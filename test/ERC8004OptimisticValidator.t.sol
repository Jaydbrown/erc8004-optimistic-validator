// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

import {BondedAssertion} from "../src/BondedAssertion.sol";
import {AgentWorkEscalationManager} from "../src/AgentWorkEscalationManager.sol";
import {ERC8004OptimisticValidator} from "../src/ERC8004OptimisticValidator.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockValidationRegistry} from "./mocks/MockValidationRegistry.sol";

contract ERC8004OptimisticValidatorTest is Test {
    bytes32 private constant TASK_ENGAGEMENT_TYPEHASH =
        keccak256("TaskEngagement(uint256 agentId,bytes32 requestHash,address client,uint256 deadline)");
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    BondedAssertion internal bondedAssertion;
    MockERC20 internal token;
    MockValidationRegistry internal registry;
    AgentWorkEscalationManager internal manager;
    ERC8004OptimisticValidator internal validator;

    address internal council = makeAddr("council");
    address internal agent = makeAddr("agent");
    address internal client;
    uint256 internal clientPk;
    address internal stranger = makeAddr("stranger");

    uint256 internal constant AGENT_ID = 1;
    uint256 internal constant BOND = 1_000e18;
    uint64 internal constant LIVENESS = 1 days;

    function setUp() public {
        bondedAssertion = new BondedAssertion();
        token = new MockERC20();
        registry = new MockValidationRegistry();
        validator =
            new ERC8004OptimisticValidator(address(registry), address(bondedAssertion), address(token), LIVENESS);
        manager = new AgentWorkEscalationManager(address(bondedAssertion), address(validator), council);
        validator.setEscalationManager(address(manager));

        (client, clientPk) = makeAddrAndKey("client");

        token.mint(agent, 10_000e18);
        vm.prank(agent);
        token.approve(address(validator), type(uint256).max);
    }

    // ── helpers ──────────────────────────────────────────────────────────────

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

    function _signEngagement(uint256 pk, uint256 agentId, bytes32 requestHash, address clientAddr, uint256 deadline)
        internal
        view
        returns (bytes memory sig)
    {
        bytes32 structHash = keccak256(abi.encode(TASK_ENGAGEMENT_TYPEHASH, agentId, requestHash, clientAddr, deadline));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, digest);
        sig = abi.encodePacked(r, s, v);
    }

    function _requestHash(string memory salt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(salt));
    }

    function _requestAndPropose(bytes32 requestHash, uint256 deadline, uint256 bond)
        internal
        returns (bytes32 assertionId)
    {
        registry.validationRequest(address(validator), AGENT_ID, "ipfs://request-evidence", requestHash);

        bytes memory sig = _signEngagement(clientPk, AGENT_ID, requestHash, client, deadline);
        vm.prank(agent);
        assertionId =
            validator.proposeOutcome(AGENT_ID, requestHash, client, deadline, sig, "ipfs://response-evidence", bond);
    }

    // ── proposeOutcome ───────────────────────────────────────────────────────

    function test_ProposeOutcome_SucceedsWithValidSignature() public {
        bytes32 requestHash = _requestHash("task-1");
        uint256 agentBalBefore = token.balanceOf(agent);

        bytes32 assertionId = _requestAndPropose(requestHash, block.timestamp + 1 hours, BOND);

        assertTrue(assertionId != bytes32(0));
        assertEq(token.balanceOf(agent), agentBalBefore - BOND);

        ERC8004OptimisticValidator.RequestState memory r = validator.getRequest(requestHash);
        assertEq(uint8(r.status), uint8(ERC8004OptimisticValidator.RequestStatus.Proposed));
        assertEq(r.client, client);
        assertEq(r.assertionId, assertionId);
    }

    function test_ProposeOutcome_RevertsOnFakeClientSignature() public {
        // Agent tries to self-declare a colluding "client" but signs with a
        // DIFFERENT key than the one bound to the `client` address argument —
        // simulates an agent trying to fabricate dispute rights out of thin
        // air rather than obtaining a real client commitment.
        bytes32 requestHash = _requestHash("task-fake-client");
        uint256 deadline = block.timestamp + 1 hours;
        registry.validationRequest(address(validator), AGENT_ID, "ipfs://request-evidence", requestHash);

        (, uint256 attackerPk) = makeAddrAndKey("attacker");
        bytes memory forgedSig = _signEngagement(attackerPk, AGENT_ID, requestHash, client, deadline);

        vm.prank(agent);
        vm.expectRevert(bytes("bad client signature"));
        validator.proposeOutcome(AGENT_ID, requestHash, client, deadline, forgedSig, "ipfs://response-evidence", BOND);
    }

    function test_ProposeOutcome_RevertsAfterEngagementDeadline() public {
        bytes32 requestHash = _requestHash("task-expired");
        uint256 deadline = block.timestamp + 1 hours;
        registry.validationRequest(address(validator), AGENT_ID, "ipfs://request-evidence", requestHash);
        bytes memory sig = _signEngagement(clientPk, AGENT_ID, requestHash, client, deadline);

        vm.warp(deadline + 1);
        vm.prank(agent);
        vm.expectRevert(bytes("engagement expired"));
        validator.proposeOutcome(AGENT_ID, requestHash, client, deadline, sig, "ipfs://response-evidence", BOND);
    }

    function test_ProposeOutcome_RevertsOnDuplicateRequestHash() public {
        bytes32 requestHash = _requestHash("task-dup");
        _requestAndPropose(requestHash, block.timestamp + 1 hours, BOND);

        bytes memory sig = _signEngagement(clientPk, AGENT_ID, requestHash, client, block.timestamp + 1 hours);
        vm.prank(agent);
        vm.expectRevert(bytes("already proposed"));
        validator.proposeOutcome(
            AGENT_ID, requestHash, client, block.timestamp + 1 hours, sig, "ipfs://response-evidence", BOND
        );
    }

    function test_ProposeOutcome_RevertsIfEscalationManagerNotSet() public {
        ERC8004OptimisticValidator freshValidator =
            new ERC8004OptimisticValidator(address(registry), address(bondedAssertion), address(token), LIVENESS);

        bytes32 requestHash = _requestHash("task-no-manager");
        uint256 deadline = block.timestamp + 1 hours;
        registry.validationRequest(address(freshValidator), AGENT_ID, "ipfs://request-evidence", requestHash);

        vm.prank(agent);
        token.approve(address(freshValidator), type(uint256).max);

        bytes32 structHash = keccak256(abi.encode(TASK_ENGAGEMENT_TYPEHASH, AGENT_ID, requestHash, client, deadline));
        bytes32 domainSeparator = keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes("ERC8004OptimisticValidator")),
                keccak256(bytes("1")),
                block.chainid,
                address(freshValidator)
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(clientPk, digest);
        bytes memory sig = abi.encodePacked(r, s, v);

        vm.prank(agent);
        vm.expectRevert(bytes("escalation manager not set"));
        freshValidator.proposeOutcome(AGENT_ID, requestHash, client, deadline, sig, "ipfs://response-evidence", BOND);
    }

    function test_SetEscalationManager_OnlyOwner() public {
        ERC8004OptimisticValidator freshValidator =
            new ERC8004OptimisticValidator(address(registry), address(bondedAssertion), address(token), LIVENESS);

        vm.prank(stranger);
        vm.expectRevert();
        freshValidator.setEscalationManager(address(manager));
    }

    function test_SetEscalationManager_RevertsIfAlreadySet() public {
        vm.expectRevert(bytes("already set"));
        validator.setEscalationManager(address(manager));
    }

    // ── end-to-end: undisputed acceptance ───────────────────────────────────

    function test_EndToEnd_UndisputedResolvesAcceptedAndWritesValidationResponse() public {
        bytes32 requestHash = _requestHash("task-accept");
        bytes32 assertionId = _requestAndPropose(requestHash, block.timestamp + 1 hours, BOND);

        vm.warp(block.timestamp + LIVENESS + 1);
        bondedAssertion.settleAssertion(assertionId);

        (address validatorAddress,, uint8 response,,,) = registry.getValidationStatus(requestHash);
        assertEq(validatorAddress, address(validator));
        assertEq(response, 100);

        ERC8004OptimisticValidator.RequestState memory r = validator.getRequest(requestHash);
        assertEq(uint8(r.status), uint8(ERC8004OptimisticValidator.RequestStatus.Resolved));
    }

    // ── end-to-end: client dispute ──────────────────────────────────────────

    function test_EndToEnd_ClientDisputeResolvesRejectedAndWritesValidationResponse() public {
        bytes32 requestHash = _requestHash("task-reject");
        bytes32 assertionId = _requestAndPropose(requestHash, block.timestamp + 1 hours, BOND);

        vm.prank(client);
        bondedAssertion.disputeAssertion(assertionId);

        (,, uint8 response,,,) = registry.getValidationStatus(requestHash);
        assertEq(response, 0);
    }

    function test_EndToEnd_NonClientCannotDispute() public {
        bytes32 requestHash = _requestHash("task-reject-blocked");
        bytes32 assertionId = _requestAndPropose(requestHash, block.timestamp + 1 hours, BOND);

        vm.prank(stranger);
        vm.expectRevert(bytes("dispute not allowed"));
        bondedAssertion.disputeAssertion(assertionId);
    }

    // ── end-to-end: council override ────────────────────────────────────────

    function test_EndToEnd_CouncilOverrideRefiresValidationResponse() public {
        bytes32 requestHash = _requestHash("task-override");
        bytes32 assertionId = _requestAndPropose(requestHash, block.timestamp + 1 hours, BOND);

        vm.prank(client);
        bondedAssertion.disputeAssertion(assertionId); // resolves rejected (0)

        (,, uint8 responseAfterDispute,,,) = registry.getValidationStatus(requestHash);
        assertEq(responseAfterDispute, 0);

        vm.prank(agent);
        manager.counterDispute(assertionId, "ipfs://counter-evidence");

        vm.prank(council);
        manager.resolveOverride(assertionId, true); // council sides with the agent

        (,, uint8 responseAfterOverride,,,) = registry.getValidationStatus(requestHash);
        assertEq(responseAfterOverride, 100);

        ERC8004OptimisticValidator.RequestState memory r = validator.getRequest(requestHash);
        assertEq(uint8(r.status), uint8(ERC8004OptimisticValidator.RequestStatus.Resolved));
    }

    // ── callback access control ──────────────────────────────────────────────

    function test_AssertionResolvedCallback_OnlyCallableByBondedAssertion() public {
        bytes32 requestHash = _requestHash("task-callback-guard");
        _requestAndPropose(requestHash, block.timestamp + 1 hours, BOND);

        vm.expectRevert(bytes("only bonded assertion"));
        validator.assertionResolvedCallback(keccak256("not-a-real-assertion"), true);
    }
}
