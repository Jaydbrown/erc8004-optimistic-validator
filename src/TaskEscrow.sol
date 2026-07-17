// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ERC8004OptimisticValidator} from "./ERC8004OptimisticValidator.sol";
import {IBondedAssertion} from "./interfaces/IBondedAssertion.sol";

/// @title TaskEscrow
/// @notice Generic, domain-agnostic pay-on-completion escrow for a single
/// task. Locks a client's payment against a requestHash, then releases it to
/// the agent if ERC8004OptimisticValidator resolves that requestHash as
/// accepted, or refunds the client if it resolves as rejected.
///
/// Deliberately carries zero task-type-specific logic: what the task
/// actually was (a code review, a monitoring report, anything) lives
/// entirely off-chain in the evidence behind requestHash. This contract only
/// ever asks "did the validator resolve this hash truthfully," never "what
/// was the task."
///
/// KNOWN v1 LIMITATION: reads the assertion's `truthful` flag at settlement
/// time. If the arbitration council later overrides a resolution (see
/// AgentWorkEscalationManager.resolveOverride) *after* this contract has
/// already settled, the payout already happened and is not revisited —
/// mirroring BondedAssertion's own documented limitation that overrides
/// don't claw back funds that already moved.
contract TaskEscrow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum Status {
        None,
        Funded,
        Settled
    }

    struct Task {
        address client;
        address agent;
        IERC20 token;
        uint256 amount;
        Status status;
    }

    ERC8004OptimisticValidator public immutable VALIDATOR;
    IBondedAssertion public immutable BONDED_ASSERTION;

    mapping(bytes32 => Task) public tasks;

    event TaskFunded(
        bytes32 indexed requestHash, address indexed client, address indexed agent, address token, uint256 amount
    );
    event TaskSettled(bytes32 indexed requestHash, bool releasedToAgent, uint256 amount);

    constructor(address validator_, address bondedAssertion_) {
        require(validator_ != address(0), "bad validator");
        require(bondedAssertion_ != address(0), "bad bondedAssertion");
        VALIDATOR = ERC8004OptimisticValidator(validator_);
        BONDED_ASSERTION = IBondedAssertion(bondedAssertion_);
    }

    /// @notice Client locks payment for a task identified by `requestHash`.
    /// Can be called any time relative to the validator flow — settle()
    /// simply has nothing to pay out until the validator resolves the hash.
    function fundTask(bytes32 requestHash, address agent, IERC20 token, uint256 amount) external nonReentrant {
        require(tasks[requestHash].status == Status.None, "already funded");
        require(agent != address(0), "bad agent");
        require(amount > 0, "bad amount");

        tasks[requestHash] =
            Task({client: msg.sender, agent: agent, token: token, amount: amount, status: Status.Funded});

        token.safeTransferFrom(msg.sender, address(this), amount);

        emit TaskFunded(requestHash, msg.sender, agent, address(token), amount);
    }

    /// @notice Releases the locked payment once the validator has resolved
    /// `requestHash` — to the agent if accepted, back to the client if
    /// rejected. Callable by anyone, matching BondedAssertion.settleAssertion's
    /// keeper-friendly pattern.
    /// @dev Requires the validator's bound client for this requestHash to
    /// match the address that funded this escrow — this is what prevents a
    /// mismatch between who has real dispute rights over the work and who
    /// receives the refund if it's rejected.
    function settle(bytes32 requestHash) external nonReentrant {
        Task storage t = tasks[requestHash];
        require(t.status == Status.Funded, "not settleable");

        ERC8004OptimisticValidator.RequestState memory r = VALIDATOR.getRequest(requestHash);
        require(r.status == ERC8004OptimisticValidator.RequestStatus.Resolved, "not resolved");
        require(r.client == t.client, "client mismatch");

        IBondedAssertion.Assertion memory a = BONDED_ASSERTION.getAssertion(r.assertionId);

        t.status = Status.Settled;
        address recipient = a.truthful ? t.agent : t.client;
        t.token.safeTransfer(recipient, t.amount);

        emit TaskSettled(requestHash, a.truthful, t.amount);
    }

    function getTask(bytes32 requestHash) external view returns (Task memory) {
        return tasks[requestHash];
    }
}
