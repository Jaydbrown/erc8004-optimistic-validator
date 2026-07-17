// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {BondedAssertion} from "../src/BondedAssertion.sol";
import {AgentWorkEscalationManager} from "../src/AgentWorkEscalationManager.sol";
import {ERC8004OptimisticValidator} from "../src/ERC8004OptimisticValidator.sol";
import {TaskEscrow} from "../src/TaskEscrow.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockValidationRegistry} from "./mocks/MockValidationRegistry.sol";

contract TaskEscrowTest is Test {
    bytes32 private constant TASK_ENGAGEMENT_TYPEHASH =
        keccak256("TaskEngagement(uint256 agentId,bytes32 requestHash,address client,uint256 deadline)");
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    BondedAssertion internal bondedAssertion;
    MockERC20 internal bondToken;
    MockERC20 internal paymentToken;
    MockValidationRegistry internal registry;
    AgentWorkEscalationManager internal manager;
    ERC8004OptimisticValidator internal validator;
    TaskEscrow internal escrow;

    address internal council = makeAddr("council");
    address internal agent = makeAddr("agent");
    address internal client;
    uint256 internal clientPk;
    address internal stranger = makeAddr("stranger");

    uint256 internal constant AGENT_ID = 1;
    uint256 internal constant BOND = 1_000e18;
    uint256 internal constant PAYMENT = 500e18;
    uint64 internal constant LIVENESS = 1 days;

    function setUp() public {
        bondedAssertion = new BondedAssertion();
        bondToken = new MockERC20("Test Token", "TEST");
        paymentToken = new MockERC20("Test Token", "TEST");
        registry = new MockValidationRegistry();
        validator =
            new ERC8004OptimisticValidator(address(registry), address(bondedAssertion), address(bondToken), LIVENESS);
        manager = new AgentWorkEscalationManager(address(bondedAssertion), address(validator), council);
        validator.setEscalationManager(address(manager));
        escrow = new TaskEscrow(address(validator), address(bondedAssertion));

        (client, clientPk) = makeAddrAndKey("client");

        bondToken.mint(agent, 10_000e18);
        vm.prank(agent);
        bondToken.approve(address(validator), type(uint256).max);

        paymentToken.mint(client, 10_000e18);
        vm.prank(client);
        paymentToken.approve(address(escrow), type(uint256).max);
    }

    function _domainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("ERC8004OptimisticValidator")),
                keccak256(bytes("1")),
                block.chainid,
                address(validator)
            )
        );
    }

    function _signEngagement(uint256 pk, bytes32 requestHash, address clientAddr, uint256 deadline)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 structHash =
            keccak256(abi.encode(TASK_ENGAGEMENT_TYPEHASH, AGENT_ID, requestHash, clientAddr, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function _requestHash(string memory salt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(salt));
    }

    function _fundProposeAndReturn(bytes32 requestHash, uint256 deadline) internal returns (bytes32 assertionId) {
        vm.prank(client);
        escrow.fundTask(requestHash, agent, paymentToken, PAYMENT);

        registry.validationRequest(address(validator), AGENT_ID, "ipfs://request-evidence", requestHash);
        bytes memory sig = _signEngagement(clientPk, requestHash, client, deadline);
        vm.prank(agent);
        assertionId =
            validator.proposeOutcome(AGENT_ID, requestHash, client, deadline, sig, "ipfs://response-evidence", BOND);
    }

    // ── fundTask ─────────────────────────────────────────────────────────────

    function test_FundTask_StoresTaskAndPullsPayment() public {
        bytes32 requestHash = _requestHash("task-fund");
        uint256 clientBalBefore = paymentToken.balanceOf(client);

        vm.prank(client);
        escrow.fundTask(requestHash, agent, paymentToken, PAYMENT);

        assertEq(paymentToken.balanceOf(client), clientBalBefore - PAYMENT);
        assertEq(paymentToken.balanceOf(address(escrow)), PAYMENT);

        TaskEscrow.Task memory t = escrow.getTask(requestHash);
        assertEq(t.client, client);
        assertEq(t.agent, agent);
        assertEq(t.amount, PAYMENT);
        assertEq(uint8(t.status), uint8(TaskEscrow.Status.Funded));
    }

    function test_FundTask_RevertsOnDuplicateRequestHash() public {
        bytes32 requestHash = _requestHash("task-dup");
        vm.prank(client);
        escrow.fundTask(requestHash, agent, paymentToken, PAYMENT);

        vm.prank(client);
        vm.expectRevert(bytes("already funded"));
        escrow.fundTask(requestHash, agent, paymentToken, PAYMENT);
    }

    // ── settle ───────────────────────────────────────────────────────────────

    function test_Settle_RevertsIfNeverFunded() public {
        bytes32 requestHash = _requestHash("task-unfunded");
        vm.expectRevert(bytes("not settleable"));
        escrow.settle(requestHash);
    }

    function test_Settle_RevertsIfNotYetResolved() public {
        bytes32 requestHash = _requestHash("task-pending");
        _fundProposeAndReturn(requestHash, block.timestamp + 1 hours);

        vm.expectRevert(bytes("not resolved"));
        escrow.settle(requestHash);
    }

    function test_Settle_RevertsOnClientMismatch() public {
        // A different address funds the escrow than the one actually bound
        // as the dispute-rights client for this requestHash — settle must
        // refuse to pay out rather than silently trusting whichever address
        // happened to call fundTask.
        bytes32 requestHash = _requestHash("task-mismatch");
        uint256 deadline = block.timestamp + 1 hours;

        vm.prank(stranger);
        paymentToken.mint(stranger, PAYMENT);
        vm.prank(stranger);
        paymentToken.approve(address(escrow), PAYMENT);
        vm.prank(stranger);
        escrow.fundTask(requestHash, agent, paymentToken, PAYMENT);

        registry.validationRequest(address(validator), AGENT_ID, "ipfs://request-evidence", requestHash);
        bytes memory sig = _signEngagement(clientPk, requestHash, client, deadline);
        vm.prank(agent);
        validator.proposeOutcome(AGENT_ID, requestHash, client, deadline, sig, "ipfs://response-evidence", BOND);

        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(validator.getRequest(requestHash).assertionId);

        vm.expectRevert(bytes("client mismatch"));
        escrow.settle(requestHash);
    }

    function test_Settle_RevertsIfAlreadySettled() public {
        bytes32 requestHash = _requestHash("task-double-settle");
        bytes32 assertionId = _fundProposeAndReturn(requestHash, block.timestamp + 1 hours);

        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);
        escrow.settle(requestHash);

        vm.expectRevert(bytes("not settleable"));
        escrow.settle(requestHash);
    }

    // ── end-to-end ───────────────────────────────────────────────────────────

    function test_EndToEnd_UndisputedReleasesPaymentToAgent() public {
        bytes32 requestHash = _requestHash("task-accept");
        bytes32 assertionId = _fundProposeAndReturn(requestHash, block.timestamp + 1 hours);

        uint256 agentBalBefore = paymentToken.balanceOf(agent);

        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);
        escrow.settle(requestHash);

        assertEq(paymentToken.balanceOf(agent), agentBalBefore + PAYMENT);
        assertEq(uint8(escrow.getTask(requestHash).status), uint8(TaskEscrow.Status.Settled));
    }

    function test_EndToEnd_ClientDisputeRefundsClient() public {
        bytes32 requestHash = _requestHash("task-reject");
        bytes32 assertionId = _fundProposeAndReturn(requestHash, block.timestamp + 1 hours);

        uint256 clientBalBefore = paymentToken.balanceOf(client);

        vm.prank(client);
        bondedAssertion.disputeAssertion(assertionId);
        escrow.settle(requestHash);

        assertEq(paymentToken.balanceOf(client), clientBalBefore + PAYMENT);
        assertEq(uint8(escrow.getTask(requestHash).status), uint8(TaskEscrow.Status.Settled));
    }

    function test_Settle_CallableByAnyone() public {
        bytes32 requestHash = _requestHash("task-keeper");
        bytes32 assertionId = _fundProposeAndReturn(requestHash, block.timestamp + 1 hours);

        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        vm.prank(stranger);
        escrow.settle(requestHash);

        assertEq(uint8(escrow.getTask(requestHash).status), uint8(TaskEscrow.Status.Settled));
    }
}
