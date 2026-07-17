// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IEscalationPolicy
/// @notice Dispute-eligibility policy consulted by IBondedAssertion. Shaped
/// after (but not identical to) UMA's EscalationManagerInterface — narrowed
/// to the one thing this design actually needs: deciding *who* may dispute
/// a given assertion. This contract does not vote or arbitrate; for
/// AgentWorkEscalationManager specifically, a valid dispute call from the
/// registered disputer *is* the adjudication (see its NatSpec).
interface IEscalationPolicy {
    function isDisputeAllowed(bytes32 assertionId, address disputeCaller) external view returns (bool);
}
