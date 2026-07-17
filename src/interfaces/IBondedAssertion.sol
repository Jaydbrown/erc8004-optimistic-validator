// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title IBondedAssertion
/// @notice A minimal assert/bond/liveness/dispute/resolve primitive. Shaped
/// as a subset of UMA's OptimisticOracleV3Interface (assertTruth /
/// disputeAssertion / settleAssertion / callback-on-resolution) so that a
/// migration to real UMA OOv3 later (if it deploys on this chain) can swap
/// the implementation behind this interface without touching callers.
///
/// Unlike OOv3, dispute *eligibility* and dispute *outcome* are both fully
/// delegated to the assertion's IEscalationPolicy — this contract holds no
/// opinion on who may dispute or how a dispute resolves. It only owns bond
/// custody, the liveness timer, and state transitions.
interface IBondedAssertion {
    enum Status {
        None,
        Proposed,
        Resolved
    }

    struct Assertion {
        bytes claim;
        address asserter;
        address callbackRecipient;
        address escalationPolicy;
        IERC20 currency;
        uint256 bond;
        uint64 expirationTime; // asserter can settle-as-true after this timestamp
        Status status;
        bool truthful; // meaningful only once status == Resolved
        bool overridden;
    }

    event AssertionMade(
        bytes32 indexed assertionId,
        bytes claim,
        address indexed asserter,
        address callbackRecipient,
        address indexed escalationPolicy,
        uint256 bond,
        uint64 expirationTime
    );
    event AssertionDisputed(bytes32 indexed assertionId, address indexed disputer);
    event AssertionSettled(bytes32 indexed assertionId, bool truthful, address bondRecipient);
    event AssertionOverridden(bytes32 indexed assertionId, bool truthful);

    /// @notice Posts a bonded claim. Reverts unless the caller has approved
    /// this contract for at least `bond` of `currency`.
    /// @return assertionId Deterministic id derived from the call parameters and a nonce.
    function assertTruth(
        bytes calldata claim,
        address asserter,
        address callbackRecipient,
        address escalationPolicy,
        uint64 liveness,
        IERC20 currency,
        uint256 bond
    ) external returns (bytes32 assertionId);

    /// @notice Disputes an assertion before its liveness window expires.
    /// Reverts unless `IEscalationPolicy(escalationPolicy).isDisputeAllowed(assertionId, msg.sender)`
    /// returns true. A valid dispute resolves the assertion to `truthful = false`
    /// immediately — this contract does not itself arbitrate; eligibility to
    /// dispute *is* the adjudication for this design (see AgentWorkEscalationManager).
    function disputeAssertion(bytes32 assertionId) external;

    /// @notice Settles an undisputed assertion as true once its liveness window
    /// has passed. Callable by anyone; the bond returns to the original asserter.
    function settleAssertion(bytes32 assertionId) external;

    /// @notice Corrects a previously resolved assertion's outcome. Callable only
    /// by the assertion's own escalationPolicy contract, which is expected to
    /// gate this itself (e.g. to a known arbitration council). Re-fires the
    /// resolution callback with the corrected value. Does not attempt to
    /// claw back or redistribute bond funds already transferred on the
    /// original resolution — see AgentWorkEscalationManager's NatSpec for why
    /// that's an explicit v1 limitation, not an oversight. Callable at most
    /// once per assertion.
    function overrideResolution(bytes32 assertionId, bool truthful) external;

    function getAssertion(bytes32 assertionId) external view returns (Assertion memory);
}

/// @notice Implemented by `callbackRecipient` to learn when an assertion resolves.
interface IBondedAssertionCallbackRecipient {
    function assertionResolvedCallback(bytes32 assertionId, bool truthful) external;
}
