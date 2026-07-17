// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBondedAssertion, IBondedAssertionCallbackRecipient} from "../../src/interfaces/IBondedAssertion.sol";

/// @notice Attempts to re-enter BondedAssertion.settleAssertion from within
/// the resolution callback, to prove the nonReentrant guard holds.
contract ReentrantCallbackRecipient is IBondedAssertionCallbackRecipient {
    IBondedAssertion public immutable TARGET;
    bytes32 public reenterAssertionId;
    bool public reenterOnCallback;

    constructor(address target) {
        TARGET = IBondedAssertion(target);
    }

    function arm(bytes32 assertionId) external {
        reenterAssertionId = assertionId;
        reenterOnCallback = true;
    }

    function assertionResolvedCallback(bytes32, bool) external override {
        if (reenterOnCallback) {
            reenterOnCallback = false;
            // Reentrant call must revert due to BondedAssertion's nonReentrant guard.
            TARGET.settleAssertion(reenterAssertionId);
        }
    }
}
