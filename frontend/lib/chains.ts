import { defineChain } from "viem";

export const appChain = defineChain({
  id: Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? 31337),
  name: Number(process.env.NEXT_PUBLIC_CHAIN_ID ?? 31337) === 31337 ? "Anvil Local" : "Monad Testnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [process.env.NEXT_PUBLIC_RPC_URL ?? "http://127.0.0.1:8545"] } },
  testnet: true,
});
