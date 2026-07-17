// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";

import {BondedAssertion} from "../src/BondedAssertion.sol";
import {AgentWorkEscalationManager} from "../src/AgentWorkEscalationManager.sol";
import {ERC8004OptimisticValidator} from "../src/ERC8004OptimisticValidator.sol";
import {TaskEscrow} from "../src/TaskEscrow.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";
import {MockValidationRegistry} from "../test/mocks/MockValidationRegistry.sol";

/// @notice Deploys the full stack to whatever chain RPC_URL points at.
///
/// Role addresses (agent/client/council) are read from environment
/// variables (AGENT_ADDRESS / CLIENT_ADDRESS / COUNCIL_ADDRESS). On local
/// Anvil (chain id 31337) these default to Anvil's well-known, publicly
/// documented test accounts — fine there, because anyone can already control
/// those keys locally. On every other chain, real addresses are REQUIRED;
/// the script reverts rather than silently reusing Anvil's public-key
/// addresses, since ARBITRATION_COUNCIL in particular is set once in
/// AgentWorkEscalationManager's constructor and can never be changed
/// afterward — deploying it pointed at a publicly-known key would let
/// anyone override validation outcomes.
///
/// Bonds and payments both settle in the same token, deployed here as
/// "Wrapped MON" — this project targets Monad, so the unit of value
/// throughout the app is MON, not an arbitrary mock asset. On a real Monad
/// deployment, swap this for the canonical WMON address (or move bonding to
/// native MON directly) rather than deploying a fresh mock.
contract Deploy is Script {
    uint64 internal constant LIVENESS = 5 minutes;

    // Anvil's well-known default accounts (mnemonic "test test test ... junk") — public, zero-value, local-only.
    address internal constant ANVIL_AGENT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant ANVIL_CLIENT = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant ANVIL_COUNCIL = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    function run() external {
        bool isLocalAnvil = block.chainid == 31337;

        address agentAddress = isLocalAnvil ? vm.envOr("AGENT_ADDRESS", ANVIL_AGENT) : vm.envAddress("AGENT_ADDRESS");
        address clientAddress =
            isLocalAnvil ? vm.envOr("CLIENT_ADDRESS", ANVIL_CLIENT) : vm.envAddress("CLIENT_ADDRESS");
        address councilAddress =
            isLocalAnvil ? vm.envOr("COUNCIL_ADDRESS", ANVIL_COUNCIL) : vm.envAddress("COUNCIL_ADDRESS");

        vm.startBroadcast();

        BondedAssertion bondedAssertion = new BondedAssertion();
        MockERC20 monToken = new MockERC20("Wrapped MON", "WMON");
        MockValidationRegistry registry = new MockValidationRegistry();

        ERC8004OptimisticValidator validator =
            new ERC8004OptimisticValidator(address(registry), address(bondedAssertion), address(monToken), LIVENESS);

        AgentWorkEscalationManager manager =
            new AgentWorkEscalationManager(address(bondedAssertion), address(validator), councilAddress);

        validator.setEscalationManager(address(manager));

        TaskEscrow escrow = new TaskEscrow(address(validator), address(bondedAssertion));

        // Seed the role addresses so the frontend has funds to click through with.
        monToken.mint(agentAddress, 100_000e18);
        if (clientAddress != agentAddress) monToken.mint(clientAddress, 100_000e18);

        vm.stopBroadcast();

        console.log("BondedAssertion:            ", address(bondedAssertion));
        console.log("MON token (WMON):           ", address(monToken));
        console.log("MockValidationRegistry:     ", address(registry));
        console.log("ERC8004OptimisticValidator: ", address(validator));
        console.log("AgentWorkEscalationManager: ", address(manager));
        console.log("TaskEscrow:                 ", address(escrow));
    }
}
