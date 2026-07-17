// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEscalationPolicy} from "./interfaces/IEscalationPolicy.sol";
import {IBondedAssertion} from "./interfaces/IBondedAssertion.sol";

/// @title AgentWorkEscalationManager
/// @notice Dispute policy for agent-work validations. Deliberately does not
/// adjudicate "was the agent's work good" — nobody neutral has the context
/// to judge that cheaply. Instead it restricts dispute rights to the one
/// party who does have context: the client who commissioned the task,
/// cryptographically bound per-request by ERC8004OptimisticValidator via an
/// EIP-712 signature before this contract ever sees the assertion. A valid
/// dispute call from that bound client *is* the adjudication — see
/// BondedAssertion.disputeAssertion, which resolves to `truthful = false`
/// immediately on an allowed dispute, with no token-holder vote or other
/// external oracle involved in the common path.
///
/// The only additional adjudication this contract performs is the rare
/// counter-dispute path: if the agent believes its bound client rejected in
/// bad faith, it can raise a counter-dispute, and a small known multisig
/// ("arbitration council") may override the resolution. This is an explicit,
/// disclosed centralization trade-off for v1 — a decentralized challenger
/// pool or real DVM routing is a v2 problem once volume justifies outside
/// attention, not a v1 blocker.
///
/// KNOWN v1 LIMITATION: overriding a resolution via the arbitration council
/// corrects the recorded outcome (and re-fires the ERC-8004 validation
/// callback) but does NOT attempt to claw back or redistribute the bond,
/// which already moved to the disputer on the original resolution. Making a
/// wronged party financially whole after a successful override is out of
/// scope for v1 — see BondedAssertion.overrideResolution's NatSpec.
///
/// KNOWN v1 LIMITATION: disputing costs the client nothing (no anti-grief
/// deposit is required to dispute). A cheap/malicious client can reject good
/// work for free to damage an agent's reputation, with only the rare,
/// council-gated counter-dispute path as recourse. An anti-grief deposit at
/// task-engagement time is a documented fast-follow, not required to ship.
contract AgentWorkEscalationManager is IEscalationPolicy {
    IBondedAssertion public immutable BONDED_ASSERTION;
    address public immutable AUTHORIZED_REGISTRAR;
    address public immutable ARBITRATION_COUNCIL;

    mapping(bytes32 => address) public disputerOf;
    mapping(bytes32 => bool) public counterDisputed;

    event DisputerRegistered(bytes32 indexed assertionId, address indexed disputer);
    event CounterDisputeRaised(bytes32 indexed assertionId, address indexed raisedBy, string evidenceURI);
    event OverrideResolved(bytes32 indexed assertionId, bool truthful);

    modifier onlyAuthorizedRegistrar() {
        _onlyAuthorizedRegistrar();
        _;
    }

    modifier onlyArbitrationCouncil() {
        _onlyArbitrationCouncil();
        _;
    }

    constructor(address bondedAssertion_, address authorizedRegistrar_, address arbitrationCouncil_) {
        require(bondedAssertion_ != address(0), "bad bondedAssertion");
        require(authorizedRegistrar_ != address(0), "bad registrar");
        require(arbitrationCouncil_ != address(0), "bad council");
        BONDED_ASSERTION = IBondedAssertion(bondedAssertion_);
        AUTHORIZED_REGISTRAR = authorizedRegistrar_;
        ARBITRATION_COUNCIL = arbitrationCouncil_;
    }

    function _onlyAuthorizedRegistrar() internal view {
        require(msg.sender == AUTHORIZED_REGISTRAR, "not authorized registrar");
    }

    function _onlyArbitrationCouncil() internal view {
        require(msg.sender == ARBITRATION_COUNCIL, "not arbitration council");
    }

    /// @notice Binds the only address allowed to dispute `assertionId`.
    /// Callable exactly once per assertion, only by the authorized registrar
    /// (ERC8004OptimisticValidator), which must call this immediately after
    /// creating the assertion — before that, `isDisputeAllowed` denies
    /// everyone by default, which is the safe default, not an exploitable gap.
    function registerDisputer(bytes32 assertionId, address disputer) external onlyAuthorizedRegistrar {
        require(disputer != address(0), "bad disputer");
        require(disputerOf[assertionId] == address(0), "already registered");
        disputerOf[assertionId] = disputer;
        emit DisputerRegistered(assertionId, disputer);
    }

    /// @inheritdoc IEscalationPolicy
    function isDisputeAllowed(bytes32 assertionId, address disputeCaller) external view returns (bool) {
        address registered = disputerOf[assertionId];
        return registered != address(0) && registered == disputeCaller;
    }

    /// @notice Raises a counter-dispute against an already-resolved assertion.
    /// Callable only by that assertion's original asserter (the agent). Does
    /// not itself change the outcome — it only records that a counter-dispute
    /// exists, which the arbitration council can act on via `resolveOverride`.
    function counterDispute(bytes32 assertionId, string calldata evidenceURI) external {
        IBondedAssertion.Assertion memory a = BONDED_ASSERTION.getAssertion(assertionId);
        require(a.status == IBondedAssertion.Status.Resolved, "not resolved");
        require(!a.overridden, "already overridden");
        require(msg.sender == a.asserter, "not the asserter");
        require(!counterDisputed[assertionId], "already counter-disputed");

        counterDisputed[assertionId] = true;
        emit CounterDisputeRaised(assertionId, msg.sender, evidenceURI);
    }

    /// @notice Corrects a resolution after a counter-dispute. Requires a
    /// counter-dispute to have been raised first, so the council is acting on
    /// a recorded, on-chain-evidenced trigger rather than an arbitrary whim.
    function resolveOverride(bytes32 assertionId, bool truthful) external onlyArbitrationCouncil {
        require(counterDisputed[assertionId], "no counter-dispute raised");
        BONDED_ASSERTION.overrideResolution(assertionId, truthful);
        emit OverrideResolved(assertionId, truthful);
    }
}
