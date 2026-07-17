import { createConfig, http } from "wagmi";
import { injected, mock } from "wagmi/connectors";
import { appChain } from "./chains";
import { DEMO_ACCOUNTS } from "./demo-accounts";

const demoAccountList: [`0x${string}`, ...`0x${string}`[]] = [
  DEMO_ACCOUNTS.deployer,
  DEMO_ACCOUNTS.agent,
  DEMO_ACCOUNTS.client,
  DEMO_ACCOUNTS.council,
];

export const wagmiConfig = createConfig({
  chains: [appChain],
  connectors: [
    mock({ accounts: demoAccountList, features: { reconnect: true } }),
    injected(),
  ],
  transports: {
    [appChain.id]: http(),
  },
});

declare module "wagmi" {
  interface Register {
    config: typeof wagmiConfig;
  }
}
