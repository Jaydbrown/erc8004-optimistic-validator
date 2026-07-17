// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IValidationRegistry
/// @notice Minimal interface for ERC-8004's ValidationRegistry — the subset of
/// function signatures this project actually calls. Vendored (signatures only,
/// not implementation) from the official reference contract:
/// https://github.com/erc-8004/erc-8004-contracts/blob/main/contracts/ValidationRegistryUpgradeable.sol
///
/// ERC8004OptimisticValidator is registered as the `validatorAddress` for a
/// given request; only that address may call `validationResponse` for it,
/// per the registry's own access control (msg.sender == s.validatorAddress).
interface IValidationRegistry {
    function validationRequest(
        address validatorAddress,
        uint256 agentId,
        string calldata requestURI,
        bytes32 requestHash
    ) external;

    function validationResponse(
        bytes32 requestHash,
        uint8 response,
        string calldata responseURI,
        bytes32 responseHash,
        string calldata tag
    ) external;

    function getValidationStatus(bytes32 requestHash)
        external
        view
        returns (
            address validatorAddress,
            uint256 agentId,
            uint8 response,
            bytes32 responseHash,
            string memory tag,
            uint256 lastUpdate
        );
}
