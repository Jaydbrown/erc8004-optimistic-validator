import { defineChain } from "viem";

const chainId = Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? 31337);
export const isLocalAnvil = chainId === 31337;

export const appChain = defineChain({
  id: chainId,
  name: isLocalAnvil ? "Anvil Local" : "Monad Testnet",
  nativeCurrency: isLocalAnvil
    ? { name: "Ether", symbol: "ETH", decimals: 18 }
    : { name: "Monad", symbol: "MON", decimals: 18 },
  rpcUrls: { default: { http: [process.env.NEXT_PUBLIC_RPC_URL ?? "http://127.0.0.1:8545"] } },
  testnet: true,
});
