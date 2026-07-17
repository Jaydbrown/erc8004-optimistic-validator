// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IBondedAssertion, IBondedAssertionCallbackRecipient} from "./interfaces/IBondedAssertion.sol";
import {IEscalationPolicy} from "./interfaces/IEscalationPolicy.sol";

/// @title BondedAssertion
/// @notice Generic assert/bond/liveness/dispute/resolve primitive. Deliberately
/// holds no opinion about *why* an assertion is being made, who is allowed to
/// dispute it, or how a dispute is adjudicated — all of that is delegated to
/// each assertion's own `escalationPolicy` contract (see IEscalationPolicy).
/// This contract only owns bond custody, the liveness timer, and the state
/// machine: None -> Proposed -> Resolved.
///
/// This is intentionally a small, purpose-built stand-in for what would
/// otherwise be UMA's Optimistic Oracle V3 — not a copy of UMA's code. It
/// exists because OOv3 is not deployed on every chain this design targets,
/// and this design's dispute path never touches OOv3's DVM voting or Store
/// fee machinery anyway, so self-hosting UMA's full stack for unused
/// machinery would be a larger audit surface for no benefit. The interface
/// is shaped to make swapping in real OOv3 later a migration, not a rewrite.
contract BondedAssertion is IBondedAssertion, ReentrancyGuard {
    using SafeERC20 for IERC20;

    mapping(bytes32 => Assertion) private _assertions;
    uint256 private _nonce;

    modifier onlyExistingAssertion(bytes32 assertionId) {
        _requireExistingAssertion(assertionId);
        _;
    }

    function _requireExistingAssertion(bytes32 assertionId) internal view {
        require(_assertions[assertionId].status != Status.None, "unknown assertion");
    }

    /// @inheritdoc IBondedAssertion
    function assertTruth(
        bytes calldata claim,
        address asserter,
        address callbackRecipient,
        address escalationPolicy,
        uint64 liveness,
        IERC20 currency,
        uint256 bond
    ) external nonReentrant returns (bytes32 assertionId) {
        require(asserter != address(0), "bad asserter");
        require(escalationPolicy != address(0), "bad escalation policy");
        require(liveness > 0, "bad liveness");

        assertionId = keccak256(
            abi.encode(
                claim, asserter, callbackRecipient, escalationPolicy, address(currency), bond, block.timestamp, _nonce++
            )
        );

        uint64 expirationTime = uint64(block.timestamp) + liveness;

        _assertions[assertionId] = Assertion({
            claim: claim,
            asserter: asserter,
            callbackRecipient: callbackRecipient,
            escalationPolicy: escalationPolicy,
            currency: currency,
            bond: bond,
            expirationTime: expirationTime,
            status: Status.Proposed,
            truthful: false,
            overridden: false
        });

        // Bond is pulled from the caller (msg.sender), not the `asserter`
        // parameter — `asserter` is just the address credited/refunded at
        // settlement, matching OOv3's own behavior. A bridge contract that
        // collects funds from its own callers before proposing (e.g.
        // ERC8004OptimisticValidator pulling from the agent) must approve
        // this contract for `bond` before calling assertTruth.
        currency.safeTransferFrom(msg.sender, address(this), bond);

        emit AssertionMade(assertionId, claim, asserter, callbackRecipient, escalationPolicy, bond, expirationTime);
    }

    /// @inheritdoc IBondedAssertion
    function disputeAssertion(bytes32 assertionId) external nonReentrant onlyExistingAssertion(assertionId) {
        Assertion storage a = _assertions[assertionId];
        require(a.status == Status.Proposed, "not disputable");
        require(block.timestamp < a.expirationTime, "liveness expired");
        require(IEscalationPolicy(a.escalationPolicy).isDisputeAllowed(assertionId, msg.sender), "dispute not allowed");

        // A valid dispute from the party the escalation policy authorized IS
        // the adjudication for this design — there is no separate vote in
        // the common path. See AgentWorkEscalationManager's NatSpec.
        a.status = Status.Resolved;
        a.truthful = false;

        emit AssertionDisputed(assertionId, msg.sender);

        address bondRecipient = msg.sender; // the successful disputer
        uint256 bond = a.bond;
        IERC20 currency = a.currency;
        address callbackRecipient = a.callbackRecipient;

        currency.safeTransfer(bondRecipient, bond);
        emit AssertionSettled(assertionId, false, bondRecipient);

        if (callbackRecipient != address(0)) {
            IBondedAssertionCallbackRecipient(callbackRecipient).assertionResolvedCallback(assertionId, false);
        }
    }

    /// @inheritdoc IBondedAssertion
    function settleAssertion(bytes32 assertionId) external nonReentrant onlyExistingAssertion(assertionId) {
        Assertion storage a = _assertions[assertionId];
        require(a.status == Status.Proposed, "not settleable");
        require(block.timestamp >= a.expirationTime, "liveness not expired");

        a.status = Status.Resolved;
        a.truthful = true;

        address bondRecipient = a.asserter;
        uint256 bond = a.bond;
        IERC20 currency = a.currency;
        address callbackRecipient = a.callbackRecipient;

        currency.safeTransfer(bondRecipient, bond);
        emit AssertionSettled(assertionId, true, bondRecipient);

        if (callbackRecipient != address(0)) {
            IBondedAssertionCallbackRecipient(callbackRecipient).assertionResolvedCallback(assertionId, true);
        }
    }

    /// @inheritdoc IBondedAssertion
    function overrideResolution(bytes32 assertionId, bool truthful)
        external
        nonReentrant
        onlyExistingAssertion(assertionId)
    {
        Assertion storage a = _assertions[assertionId];
        require(a.status == Status.Resolved, "not yet resolved");
        require(!a.overridden, "already overridden");
        require(msg.sender == a.escalationPolicy, "only escalation policy");

        a.overridden = true;
        a.truthful = truthful;

        emit AssertionOverridden(assertionId, truthful);

        if (a.callbackRecipient != address(0)) {
            IBondedAssertionCallbackRecipient(a.callbackRecipient).assertionResolvedCallback(assertionId, truthful);
        }
    }

    /// @inheritdoc IBondedAssertion
    function getAssertion(bytes32 assertionId) external view returns (Assertion memory) {
        return _assertions[assertionId];
    }
}
