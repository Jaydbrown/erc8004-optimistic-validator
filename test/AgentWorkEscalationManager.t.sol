// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {BondedAssertion} from "../src/BondedAssertion.sol";
import {AgentWorkEscalationManager} from "../src/AgentWorkEscalationManager.sol";
import {IBondedAssertion} from "../src/interfaces/IBondedAssertion.sol";
import {MockERC20} from "./mocks/MockERC20.sol";

contract AgentWorkEscalationManagerTest is Test {
    BondedAssertion internal bondedAssertion;
    AgentWorkEscalationManager internal manager;
    MockERC20 internal token;

    address internal registrar = makeAddr("registrar"); // stands in for ERC8004OptimisticValidator
    address internal council = makeAddr("council");
    address internal agent = makeAddr("agent");
    address internal client = makeAddr("client");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant BOND = 1_000e18;
    uint64 internal constant LIVENESS = 1 days;

    function setUp() public {
        bondedAssertion = new BondedAssertion();
        manager = new AgentWorkEscalationManager(address(bondedAssertion), registrar, council);
        token = new MockERC20();

        token.mint(agent, 10_000e18);
        vm.prank(agent);
        token.approve(address(bondedAssertion), type(uint256).max);
    }

    function _makeAssertion() internal returns (bytes32 assertionId) {
        vm.prank(agent);
        assertionId = bondedAssertion.assertTruth(
            bytes("claim"), agent, address(0), address(manager), LIVENESS, IERC20(address(token)), BOND
        );
    }

    // ── registerDisputer ─────────────────────────────────────────────────────

    function test_RegisterDisputer_OnlyAuthorizedRegistrar() public {
        bytes32 assertionId = _makeAssertion();
        vm.expectRevert(bytes("not authorized registrar"));
        manager.registerDisputer(assertionId, client);
    }

    function test_RegisterDisputer_RevertsIfAlreadyRegistered() public {
        bytes32 assertionId = _makeAssertion();
        vm.prank(registrar);
        manager.registerDisputer(assertionId, client);

        vm.prank(registrar);
        vm.expectRevert(bytes("already registered"));
        manager.registerDisputer(assertionId, stranger);
    }

    function test_IsDisputeAllowed_FalseByDefault() public {
        bytes32 assertionId = _makeAssertion();
        assertFalse(manager.isDisputeAllowed(assertionId, client));
    }

    function test_IsDisputeAllowed_TrueOnlyForRegisteredDisputer() public {
        bytes32 assertionId = _makeAssertion();
        vm.prank(registrar);
        manager.registerDisputer(assertionId, client);

        assertTrue(manager.isDisputeAllowed(assertionId, client));
        assertFalse(manager.isDisputeAllowed(assertionId, stranger));
    }

    // ── end-to-end dispute through BondedAssertion ──────────────────────────

    function test_RegisteredClientCanDisputeThroughBondedAssertion() public {
        bytes32 assertionId = _makeAssertion();
        vm.prank(registrar);
        manager.registerDisputer(assertionId, client);

        vm.prank(client);
        bondedAssertion.disputeAssertion(assertionId);

        IBondedAssertion.Assertion memory a = bondedAssertion.getAssertion(assertionId);
        assertFalse(a.truthful);
    }

    function test_UnregisteredAddressCannotDisputeThroughBondedAssertion() public {
        bytes32 assertionId = _makeAssertion();
        vm.prank(registrar);
        manager.registerDisputer(assertionId, client);

        vm.prank(stranger);
        vm.expectRevert(bytes("dispute not allowed"));
        bondedAssertion.disputeAssertion(assertionId);
    }

    // ── counterDispute ───────────────────────────────────────────────────────

    function test_CounterDispute_OnlyOriginalAsserter() public {
        bytes32 assertionId = _makeAssertion();
        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        vm.prank(stranger);
        vm.expectRevert(bytes("not the asserter"));
        manager.counterDispute(assertionId, "ipfs://evidence");
    }

    function test_CounterDispute_RevertsIfNotYetResolved() public {
        bytes32 assertionId = _makeAssertion();
        vm.prank(agent);
        vm.expectRevert(bytes("not resolved"));
        manager.counterDispute(assertionId, "ipfs://evidence");
    }

    function test_CounterDispute_RevertsIfAlreadyRaised() public {
        bytes32 assertionId = _makeAssertion();
        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        vm.prank(agent);
        manager.counterDispute(assertionId, "ipfs://evidence");

        vm.prank(agent);
        vm.expectRevert(bytes("already counter-disputed"));
        manager.counterDispute(assertionId, "ipfs://more-evidence");
    }

    // ── resolveOverride ──────────────────────────────────────────────────────

    function test_ResolveOverride_OnlyArbitrationCouncil() public {
        bytes32 assertionId = _makeAssertion();
        vm.prank(registrar);
        manager.registerDisputer(assertionId, client);
        vm.prank(client);
        bondedAssertion.disputeAssertion(assertionId);

        vm.prank(agent);
        manager.counterDispute(assertionId, "ipfs://evidence");

        vm.expectRevert(bytes("not arbitration council"));
        manager.resolveOverride(assertionId, true);
    }

    function test_ResolveOverride_RevertsWithoutPriorCounterDispute() public {
        bytes32 assertionId = _makeAssertion();
        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        vm.prank(council);
        vm.expectRevert(bytes("no counter-dispute raised"));
        manager.resolveOverride(assertionId, false);
    }

    function test_ResolveOverride_FlipsBondedAssertionOutcome() public {
        bytes32 assertionId = _makeAssertion();
        vm.prank(registrar);
        manager.registerDisputer(assertionId, client);
        vm.prank(client);
        bondedAssertion.disputeAssertion(assertionId); // resolves false

        vm.prank(agent);
        manager.counterDispute(assertionId, "ipfs://evidence");

        vm.prank(council);
        manager.resolveOverride(assertionId, true); // council sides with the agent

        IBondedAssertion.Assertion memory a = bondedAssertion.getAssertion(assertionId);
        assertTrue(a.truthful);
        assertTrue(a.overridden);
    }
}
