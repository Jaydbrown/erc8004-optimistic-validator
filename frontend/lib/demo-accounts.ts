// Anvil's well-known default dev accounts (mnemonic "test test test ... junk").
// Public, zero-value, safe for local development only — never use these on a
// real chain.
export const DEMO_ACCOUNTS = {
  deployer: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  agent: "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
  client: "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC",
  council: "0x90F79bf6EB2c4f870365E785982E1f101E93b906",
} as const satisfies Record<string, `0x${string}`>;

export type Role = "agent" | "client" | "council";

export const ROLE_LABELS: Record<Role, string> = {
  agent: "Agent",
  client: "Client",
  council: "Arbitration Council",
};
