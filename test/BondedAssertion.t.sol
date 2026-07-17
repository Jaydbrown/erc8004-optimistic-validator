// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {BondedAssertion} from "../src/BondedAssertion.sol";
import {IBondedAssertion} from "../src/interfaces/IBondedAssertion.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockEscalationPolicy} from "./mocks/MockEscalationPolicy.sol";
import {ReentrantCallbackRecipient} from "./mocks/ReentrantCallbackRecipient.sol";

contract BondedAssertionTest is Test {
    BondedAssertion internal bondedAssertion;
    MockERC20 internal token;
    MockEscalationPolicy internal policy;

    address internal asserter = makeAddr("asserter");
    address internal disputer = makeAddr("disputer");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant BOND = 1_000e18;
    uint64 internal constant LIVENESS = 1 days;

    function setUp() public {
        bondedAssertion = new BondedAssertion();
        token = new MockERC20("Test Token", "TEST");
        policy = new MockEscalationPolicy();

        token.mint(asserter, 10_000e18);
        vm.prank(asserter);
        token.approve(address(bondedAssertion), type(uint256).max);
    }

    function _assertTruth() internal returns (bytes32 assertionId) {
        vm.prank(asserter);
        assertionId = bondedAssertion.assertTruth(
            bytes("claim"), asserter, address(0), address(policy), LIVENESS, IERC20(address(token)), BOND
        );
    }

    // ── assertTruth ──────────────────────────────────────────────────────────

    function test_AssertTruth_PullsBondFromCaller() public {
        uint256 asserterBalBefore = token.balanceOf(asserter);
        uint256 contractBalBefore = token.balanceOf(address(bondedAssertion));

        _assertTruth();

        assertEq(token.balanceOf(asserter), asserterBalBefore - BOND);
        assertEq(token.balanceOf(address(bondedAssertion)), contractBalBefore + BOND);
    }

    function test_AssertTruth_StoresAssertion() public {
        bytes32 assertionId = _assertTruth();
        IBondedAssertion.Assertion memory a = bondedAssertion.getAssertion(assertionId);

        assertEq(uint8(a.status), uint8(IBondedAssertion.Status.Proposed));
        assertEq(a.asserter, asserter);
        assertEq(a.bond, BOND);
        assertEq(a.escalationPolicy, address(policy));
        assertEq(a.expirationTime, uint64(block.timestamp) + LIVENESS);
        assertFalse(a.truthful);
        assertFalse(a.overridden);
    }

    function test_AssertTruth_ProducesUniqueIdsForIdenticalCalls() public {
        bytes32 id1 = _assertTruth();
        bytes32 id2 = _assertTruth();
        assertTrue(id1 != id2);
    }

    function test_AssertTruth_RevertsWithoutApproval() public {
        vm.prank(stranger);
        token.mint(stranger, BOND);
        vm.prank(stranger);
        vm.expectRevert();
        bondedAssertion.assertTruth(
            bytes("claim"), stranger, address(0), address(policy), LIVENESS, IERC20(address(token)), BOND
        );
    }

    // ── settleAssertion ──────────────────────────────────────────────────────

    function test_SettleAssertion_RevertsBeforeLivenessExpires() public {
        bytes32 assertionId = _assertTruth();
        vm.expectRevert(bytes("liveness not expired"));
        bondedAssertion.settleAssertion(assertionId);
    }

    function test_SettleAssertion_ReturnsBondToAsserterAfterLiveness() public {
        bytes32 assertionId = _assertTruth();
        uint256 asserterBalBefore = token.balanceOf(asserter);

        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        assertEq(token.balanceOf(asserter), asserterBalBefore + BOND);
        IBondedAssertion.Assertion memory a = bondedAssertion.getAssertion(assertionId);
        assertEq(uint8(a.status), uint8(IBondedAssertion.Status.Resolved));
        assertTrue(a.truthful);
    }

    function test_SettleAssertion_CallableByAnyone() public {
        bytes32 assertionId = _assertTruth();
        vm.warp(block.timestamp + LIVENESS + 1);
        vm.prank(stranger); // not the asserter, not a party to the deal
        bondedAssertion.settleAssertion(assertionId);
        IBondedAssertion.Assertion memory a = bondedAssertion.getAssertion(assertionId);
        assertEq(uint8(a.status), uint8(IBondedAssertion.Status.Resolved));
    }

    function test_SettleAssertion_RevertsIfAlreadyResolved() public {
        bytes32 assertionId = _assertTruth();
        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        vm.expectRevert(bytes("not settleable"));
        bondedAssertion.settleAssertion(assertionId);
    }

    // ── disputeAssertion ─────────────────────────────────────────────────────

    function test_DisputeAssertion_RevertsIfNotAllowed() public {
        bytes32 assertionId = _assertTruth();
        // policy has no allowed disputer registered for this assertionId
        vm.prank(disputer);
        vm.expectRevert(bytes("dispute not allowed"));
        bondedAssertion.disputeAssertion(assertionId);
    }

    function test_DisputeAssertion_ResolvesToFalseAndPaysDisputer() public {
        bytes32 assertionId = _assertTruth();
        policy.setAllowedDisputer(assertionId, disputer);

        uint256 disputerBalBefore = token.balanceOf(disputer);

        vm.prank(disputer);
        bondedAssertion.disputeAssertion(assertionId);

        assertEq(token.balanceOf(disputer), disputerBalBefore + BOND);
        IBondedAssertion.Assertion memory a = bondedAssertion.getAssertion(assertionId);
        assertEq(uint8(a.status), uint8(IBondedAssertion.Status.Resolved));
        assertFalse(a.truthful);
    }

    function test_DisputeAssertion_RevertsAfterLivenessExpires() public {
        bytes32 assertionId = _assertTruth();
        policy.setAllowedDisputer(assertionId, disputer);
        vm.warp(block.timestamp + LIVENESS + 1);

        vm.prank(disputer);
        vm.expectRevert(bytes("liveness expired"));
        bondedAssertion.disputeAssertion(assertionId);
    }

    function test_DisputeAssertion_RevertsIfCalledByWrongAddress() public {
        bytes32 assertionId = _assertTruth();
        policy.setAllowedDisputer(assertionId, disputer);

        vm.prank(stranger);
        vm.expectRevert(bytes("dispute not allowed"));
        bondedAssertion.disputeAssertion(assertionId);
    }

    // ── overrideResolution ───────────────────────────────────────────────────

    function test_OverrideResolution_OnlyCallableByEscalationPolicy() public {
        bytes32 assertionId = _assertTruth();
        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        vm.expectRevert(bytes("only escalation policy"));
        bondedAssertion.overrideResolution(assertionId, false);
    }

    function test_OverrideResolution_FlipsOutcome() public {
        bytes32 assertionId = _assertTruth();
        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        vm.prank(address(policy));
        bondedAssertion.overrideResolution(assertionId, false);

        IBondedAssertion.Assertion memory a = bondedAssertion.getAssertion(assertionId);
        assertFalse(a.truthful);
        assertTrue(a.overridden);
    }

    function test_OverrideResolution_RevertsIfAlreadyOverridden() public {
        bytes32 assertionId = _assertTruth();
        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        vm.prank(address(policy));
        bondedAssertion.overrideResolution(assertionId, false);

        vm.prank(address(policy));
        vm.expectRevert(bytes("already overridden"));
        bondedAssertion.overrideResolution(assertionId, true);
    }

    function test_OverrideResolution_RevertsIfNotYetResolved() public {
        bytes32 assertionId = _assertTruth();
        vm.prank(address(policy));
        vm.expectRevert(bytes("not yet resolved"));
        bondedAssertion.overrideResolution(assertionId, false);
    }

    // ── reentrancy ───────────────────────────────────────────────────────────

    function test_Reentrancy_SettleAssertionBlocked() public {
        ReentrantCallbackRecipient recipient = new ReentrantCallbackRecipient(address(bondedAssertion));

        vm.prank(asserter);
        bytes32 assertionId = bondedAssertion.assertTruth(
            bytes("claim"), asserter, address(recipient), address(policy), LIVENESS, IERC20(address(token)), BOND
        );
        recipient.arm(assertionId);

        vm.warp(block.timestamp + LIVENESS + 1);
        // The reentrant call the callback triggers inside settleAssertion
        // reverts on the nonReentrant guard, and because it's a plain
        // external call (not try/catch-wrapped), that revert bubbles all the
        // way back up through the callback and fails the *outer*
        // settleAssertion call too — proving the guard actually blocks the
        // reentrant attempt rather than silently swallowing it.
        vm.expectRevert(ReentrancyGuard.ReentrancyGuardReentrantCall.selector);
        bondedAssertion.settleAssertion(assertionId);
    }
}
