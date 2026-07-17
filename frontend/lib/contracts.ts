import { ERC8004OptimisticValidatorAbi } from "./abis/ERC8004OptimisticValidator";
import { TaskEscrowAbi } from "./abis/TaskEscrow";
import { AgentWorkEscalationManagerAbi } from "./abis/AgentWorkEscalationManager";
import { BondedAssertionAbi } from "./abis/BondedAssertion";
import { MockERC20Abi } from "./abis/MockERC20";
import { MockValidationRegistryAbi } from "./abis/MockValidationRegistry";

function requireAddress(name: string, value: string | undefined): `0x${string}` {
  if (!value) throw new Error(`Missing env var for ${name} — check frontend/.env.local`);
  return value as `0x${string}`;
}

export const contracts = {
  bondedAssertion: {
    address: requireAddress("BONDED_ASSERTION", process.env.NEXT_PUBLIC_BONDED_ASSERTION_ADDRESS),
    abi: BondedAssertionAbi,
  },
  bondToken: {
    address: requireAddress("BOND_TOKEN", process.env.NEXT_PUBLIC_BOND_TOKEN_ADDRESS),
    abi: MockERC20Abi,
  },
  paymentToken: {
    address: requireAddress("PAYMENT_TOKEN", process.env.NEXT_PUBLIC_PAYMENT_TOKEN_ADDRESS),
    abi: MockERC20Abi,
  },
  validationRegistry: {
    address: requireAddress("VALIDATION_REGISTRY", process.env.NEXT_PUBLIC_VALIDATION_REGISTRY_ADDRESS),
    abi: MockValidationRegistryAbi,
  },
  validator: {
    address: requireAddress("VALIDATOR", process.env.NEXT_PUBLIC_VALIDATOR_ADDRESS),
    abi: ERC8004OptimisticValidatorAbi,
  },
  escalationManager: {
    address: requireAddress("ESCALATION_MANAGER", process.env.NEXT_PUBLIC_ESCALATION_MANAGER_ADDRESS),
    abi: AgentWorkEscalationManagerAbi,
  },
  taskEscrow: {
    address: requireAddress("TASK_ESCROW", process.env.NEXT_PUBLIC_TASK_ESCROW_ADDRESS),
    abi: TaskEscrowAbi,
  },
} as const;

export const TASK_ENGAGEMENT_TYPEHASH_DOMAIN = {
  name: "ERC8004OptimisticValidator",
  version: "1",
} as const;

export const taskEngagementTypes = {
  TaskEngagement: [
    { name: "agentId", type: "uint256" },
    { name: "requestHash", type: "bytes32" },
    { name: "client", type: "address" },
    { name: "deadline", type: "uint256" },
  ],
} as const;
