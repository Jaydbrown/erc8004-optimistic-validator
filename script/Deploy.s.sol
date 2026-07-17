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
/// Local-dev only: mints bond/payment tokens to Anvil's well-known default
/// test accounts (#1 as "agent", #2 as "client") so the frontend has
/// something to interact with immediately. Never run this against a chain
/// where those addresses hold anything real.
contract Deploy is Script {
    uint64 internal constant LIVENESS = 5 minutes;

    // Anvil's well-known default accounts (mnemonic "test test test ... junk") — public, zero-value, dev-only.
    address internal constant ANVIL_AGENT = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address internal constant ANVIL_CLIENT = 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC;
    address internal constant ANVIL_COUNCIL = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    function run() external {
        vm.startBroadcast();

        BondedAssertion bondedAssertion = new BondedAssertion();
        MockERC20 bondToken = new MockERC20();
        MockERC20 paymentToken = new MockERC20();
        MockValidationRegistry registry = new MockValidationRegistry();

        ERC8004OptimisticValidator validator =
            new ERC8004OptimisticValidator(address(registry), address(bondedAssertion), address(bondToken), LIVENESS);

        AgentWorkEscalationManager manager =
            new AgentWorkEscalationManager(address(bondedAssertion), address(validator), ANVIL_COUNCIL);

        validator.setEscalationManager(address(manager));

        TaskEscrow escrow = new TaskEscrow(address(validator), address(bondedAssertion));

        // Seed the demo accounts so the frontend has funds to click through with.
        bondToken.mint(ANVIL_AGENT, 100_000e18);
        paymentToken.mint(ANVIL_CLIENT, 100_000e18);

        vm.stopBroadcast();

        console.log("BondedAssertion:            ", address(bondedAssertion));
        console.log("BondToken (MOCK):           ", address(bondToken));
        console.log("PaymentToken (MOCK):        ", address(paymentToken));
        console.log("MockValidationRegistry:     ", address(registry));
        console.log("ERC8004OptimisticValidator: ", address(validator));
        console.log("AgentWorkEscalationManager: ", address(manager));
        console.log("TaskEscrow:                 ", address(escrow));
    }
}
