# ERC-8004 Optimistic Validator — Frontend

A Next.js + wagmi/viem dapp for interacting with the contracts in `../src`.
Lets an agent, a client, and an arbitration council walk through the full
bonded-assertion + escrow flow from the browser instead of `cast`.

## Local development

1. Start a local chain:

   ```bash
   anvil
   ```

2. From the repo root, deploy the contract stack to it:

   ```bash
   forge script script/Deploy.s.sol:Deploy \
     --rpc-url http://127.0.0.1:8545 \
     --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
     --broadcast
   ```

   That private key is Anvil's well-known default account #0 — public,
   zero-value, safe for local dev only. The script also mints demo bond/payment
   tokens to Anvil's account #1 (agent) and #2 (client).

3. Copy the addresses the script logs into `frontend/.env.local` (see
   `.env.example` for the shape).

4. Run the app:

   ```bash
   cd frontend
   npm install
   npm run dev
   ```

5. Open `http://localhost:3000`, click **Connect Local Dev Wallet (Anvil)** —
   this uses wagmi's `mock` connector, which forwards signing and
   transaction-sending straight to Anvil's RPC. Anvil holds the private keys
   for its own default accounts internally, so it signs EIP-712 data and
   transactions for them without the app ever touching a private key.

## Golden path

1. **Client** tab: fill in the agent's address, fund the task, then sign the
   `TaskEngagement` (EIP-712) and copy the signature shown.
2. **Agent** tab: register the request with the mock `ValidationRegistry`,
   paste the client's address and signature, set a bond, propose the outcome.
3. Wait out the liveness window (5 minutes by default — see
   `LIVENESS` in `script/Deploy.s.sol`), or on a local Anvil chain fast-forward
   it directly:

   ```bash
   cast rpc anvil_increaseTime 301 --rpc-url http://127.0.0.1:8545
   cast rpc anvil_mine --rpc-url http://127.0.0.1:8545
   ```

4. In the **Status** panel (visible under any role), click **Settle
   Assertion**, then **Settle Escrow** — payment releases to the agent.
   If the client disputes instead (from the Status panel, before the liveness
   window closes), the escrow refunds the client instead.

## Pointing at Monad testnet later

Nothing in the frontend is hardcoded to Anvil — swap `NEXT_PUBLIC_RPC_URL`,
`NEXT_PUBLIC_CHAIN_ID`, and the contract addresses in `.env.local` once you've
deployed the stack there yourself with a real funded key (not something this
project automates).
