// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEscalationPolicy} from "../../src/interfaces/IEscalationPolicy.sol";

/// @notice Trivial, directly-controllable policy for isolated BondedAssertion
/// tests — lets a test decide who may dispute without pulling in the full
/// AgentWorkEscalationManager (which has its own dedicated test file).
contract MockEscalationPolicy is IEscalationPolicy {
    mapping(bytes32 => address) public allowedDisputer;

    function setAllowedDisputer(bytes32 assertionId, address disputer) external {
        allowedDisputer[assertionId] = disputer;
    }

    function isDisputeAllowed(bytes32 assertionId, address disputeCaller) external view override returns (bool) {
        return allowedDisputer[assertionId] == disputeCaller;
    }
}
