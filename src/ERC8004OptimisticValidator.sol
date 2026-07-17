// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IValidationRegistry} from "./interfaces/IValidationRegistry.sol";
import {IBondedAssertion, IBondedAssertionCallbackRecipient} from "./interfaces/IBondedAssertion.sol";
import {AgentWorkEscalationManager} from "./AgentWorkEscalationManager.sol";

/// @title ERC8004OptimisticValidator
/// @notice Bridges ERC-8004's ValidationRegistry to a bonded, disputable
/// assertion instead of a single blindly-trusted validator address. This
/// contract is registered as the `validatorAddress` for a request; ERC-8004's
/// registry itself enforces that only this contract may later call
/// `validationResponse` for that request.
///
/// What's actually adjudicated is deliberately narrow: not "was the agent's
/// work good" (subjective — nobody neutral has context to judge it), but
/// "did the client who commissioned the task explicitly reject the
/// deliverable, or fail to reject it within the review window" — an
/// objective, checkable fact. Quality judgment stays with the client, who
/// has context and can judge for free and instantly; this contract only
/// needs to know whether they exercised their reject right in time. See
/// AgentWorkEscalationManager for the dispute-eligibility policy that makes
/// this enforceable on-chain.
///
/// Score is intentionally binary (0 or 100) — the underlying BondedAssertion
/// primitive is a true/false claim, so fabricating an intermediate score
/// would imply precision the mechanism doesn't produce. Responses are tagged
/// "optimistic-binary-v1" so downstream reputation aggregators can tell this
/// scoring methodology apart from finer-grained validator types.
contract ERC8004OptimisticValidator is IBondedAssertionCallbackRecipient, EIP712, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IValidationRegistry public immutable VALIDATION_REGISTRY;
    IBondedAssertion public immutable BONDED_ASSERTION;
    IERC20 public immutable BOND_CURRENCY;
    uint64 public immutable LIVENESS;

    /// @dev Set once, after deployment — AgentWorkEscalationManager's own
    /// constructor requires this contract's address as its authorized
    /// registrar, so the two contracts have a circular dependency that can't
    /// be resolved purely via constructor arguments. Deploy this contract,
    /// deploy the manager pointing at this contract's address, then call
    /// `setEscalationManager` once.
    AgentWorkEscalationManager public escalationManager;

    bytes32 private constant TASK_ENGAGEMENT_TYPEHASH =
        keccak256("TaskEngagement(uint256 agentId,bytes32 requestHash,address client,uint256 deadline)");

    enum RequestStatus {
        None,
        Proposed,
        Resolved
    }

    struct RequestState {
        RequestStatus status;
        address client;
        bytes32 assertionId;
        string responseURI;
    }

    mapping(bytes32 => RequestState) public requests;
    mapping(bytes32 => bytes32) public requestHashOfAssertion;

    event EscalationManagerSet(address escalationManager);
    event OutcomeProposed(
        bytes32 indexed requestHash, bytes32 indexed assertionId, address indexed agent, address client, uint256 bond
    );
    event OutcomeResolved(bytes32 indexed requestHash, bytes32 indexed assertionId, bool truthful);

    constructor(address validationRegistry_, address bondedAssertion_, address currency_, uint64 liveness_)
        EIP712("ERC8004OptimisticValidator", "1")
        Ownable(msg.sender)
    {
        require(validationRegistry_ != address(0), "bad registry");
        require(bondedAssertion_ != address(0), "bad bondedAssertion");
        require(currency_ != address(0), "bad currency");
        require(liveness_ > 0, "bad liveness");
        VALIDATION_REGISTRY = IValidationRegistry(validationRegistry_);
        BONDED_ASSERTION = IBondedAssertion(bondedAssertion_);
        BOND_CURRENCY = IERC20(currency_);
        LIVENESS = liveness_;
    }

    /// @notice One-time wiring of the escalation manager. See the field's
    /// NatSpec for why this can't just be a constructor argument.
    function setEscalationManager(address escalationManager_) external onlyOwner {
        require(address(escalationManager) == address(0), "already set");
        require(escalationManager_ != address(0), "bad escalation manager");
        escalationManager = AgentWorkEscalationManager(escalationManager_);
        emit EscalationManagerSet(escalationManager_);
    }

    /// @notice Proposes that `client` did not reject the deliverable for
    /// `requestHash`, backed by a bond pulled from the caller (the agent).
    /// Requires an EIP-712 `TaskEngagement` signature from `client`,
    /// obtained off-chain at task-kickoff time — this is what prevents an
    /// agent from naming a colluding, fake "client" with no real dispute
    /// rights: `client` here isn't just an argument, it's the recovered
    /// signer of a commitment `client` actually made in advance.
    /// @param requestHash Must match an existing ERC-8004
    /// `ValidationRegistry.validationRequest` naming this contract as
    /// `validatorAddress` — enforced later, when `validationResponse` is
    /// called; not re-validated here to avoid an extra external call, but
    /// this function reverts on a duplicate proposal for the same requestHash.
    /// @param responseURI Evidence backing the eventual response, stored now
    /// and reused whichever way the assertion resolves (or is later overridden).
    function proposeOutcome(
        uint256 agentId,
        bytes32 requestHash,
        address client,
        uint256 deadline,
        bytes calldata clientSig,
        string calldata responseURI,
        uint256 bond
    ) external nonReentrant returns (bytes32 assertionId) {
        require(address(escalationManager) != address(0), "escalation manager not set");
        RequestState storage r = requests[requestHash];
        require(r.status == RequestStatus.None, "already proposed");
        require(block.timestamp <= deadline, "engagement expired");
        require(client != address(0), "bad client");

        bytes32 structHash = keccak256(abi.encode(TASK_ENGAGEMENT_TYPEHASH, agentId, requestHash, client, deadline));
        address signer = ECDSA.recover(_hashTypedDataV4(structHash), clientSig);
        require(signer == client, "bad client signature");

        r.status = RequestStatus.Proposed;
        r.client = client;
        r.responseURI = responseURI;

        // Bond comes directly from the agent (msg.sender), not a pooled or
        // subsidized third party — keeping the incentive un-diffused is load
        // bearing for the whole mechanism (see contract-level NatSpec).
        BOND_CURRENCY.safeTransferFrom(msg.sender, address(this), bond);
        BOND_CURRENCY.forceApprove(address(BONDED_ASSERTION), bond);

        bytes memory claim =
            abi.encode("client did not reject deliverable for requestHash", requestHash, "by deadline", deadline);

        assertionId = BONDED_ASSERTION.assertTruth(
            claim, msg.sender, address(this), address(escalationManager), LIVENESS, BOND_CURRENCY, bond
        );

        r.assertionId = assertionId;
        requestHashOfAssertion[assertionId] = requestHash;

        escalationManager.registerDisputer(assertionId, client);

        emit OutcomeProposed(requestHash, assertionId, msg.sender, client, bond);
    }

    /// @inheritdoc IBondedAssertionCallbackRecipient
    /// @dev Fires twice for an assertion that's later overridden by the
    /// arbitration council: once on original resolution, once on override.
    /// ERC-8004's `validationResponse` has no guard against being called more
    /// than once for the same requestHash — it just overwrites the stored
    /// response — so re-calling it here on override correctly corrects the
    /// on-chain record.
    function assertionResolvedCallback(bytes32 assertionId, bool truthful) external nonReentrant {
        require(msg.sender == address(BONDED_ASSERTION), "only bonded assertion");
        bytes32 requestHash = requestHashOfAssertion[assertionId];
        require(requestHash != bytes32(0), "unknown assertion");

        RequestState storage r = requests[requestHash];
        require(r.status == RequestStatus.Proposed || r.status == RequestStatus.Resolved, "bad state");

        r.status = RequestStatus.Resolved;
        uint8 response = truthful ? 100 : 0;

        VALIDATION_REGISTRY.validationResponse(
            requestHash, response, r.responseURI, keccak256(bytes(r.responseURI)), "optimistic-binary-v1"
        );

        emit OutcomeResolved(requestHash, assertionId, truthful);
    }

    function getRequest(bytes32 requestHash) external view returns (RequestState memory) {
        return requests[requestHash];
    }
}
