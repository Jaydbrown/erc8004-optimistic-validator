"use client";

import { useState } from "react";
import { useAccount, useReadContract, useSignTypedData, useWriteContractSync } from "wagmi";
import { parseUnits } from "viem";
import { contracts, taskEngagementTypes } from "@/lib/contracts";
import { appChain } from "@/lib/chains";
import { useRole } from "@/contexts/role-context";

interface Props {
  requestHash: `0x${string}`;
  agentId: string;
  deadline: bigint;
}

export function ClientPanel({ requestHash, agentId, deadline }: Props) {
  const { activeAddress } = useRole();
  const { chainId } = useAccount();
  const [agentAddress, setAgentAddress] = useState("");
  const [amount, setAmount] = useState("500");
  const [signature, setSignature] = useState<string>("");
  const [log, setLog] = useState<string>("");

  const { mutateAsync: signTypedDataAsync } = useSignTypedData();
  const { mutateAsync: writeAsync, isPending } = useWriteContractSync();

  const { data: allowance } = useReadContract({
    ...contracts.paymentToken,
    functionName: "allowance",
    args: activeAddress ? [activeAddress, contracts.taskEscrow.address] : undefined,
    query: { enabled: !!activeAddress },
  });

  async function handleFund() {
    if (!activeAddress || !agentAddress) return;
    setLog("Funding task…");
    try {
      const amountWei = parseUnits(amount || "0", 18);
      if (!allowance || (allowance as bigint) < amountWei) {
        setLog("Approving payment token…");
        await writeAsync({
          ...contracts.paymentToken,
          functionName: "approve",
          args: [contracts.taskEscrow.address, amountWei],
          account: activeAddress,
        });
      }
      setLog("Locking payment in TaskEscrow…");
      await writeAsync({
        ...contracts.taskEscrow,
        functionName: "fundTask",
        args: [requestHash, agentAddress as `0x${string}`, contracts.paymentToken.address, amountWei],
        account: activeAddress,
      });
      setLog("Task funded.");
    } catch (err) {
      setLog(`Error: ${(err as Error).message}`);
    }
  }

  async function handleSignEngagement() {
    if (!activeAddress) return;
    setLog("Signing TaskEngagement…");
    try {
      const sig = await signTypedDataAsync({
        account: activeAddress,
        domain: {
          name: "ERC8004OptimisticValidator",
          version: "1",
          chainId: chainId ?? appChain.id,
          verifyingContract: contracts.validator.address,
        },
        types: taskEngagementTypes,
        primaryType: "TaskEngagement",
        message: {
          agentId: BigInt(agentId || "0"),
          requestHash,
          client: activeAddress,
          deadline,
        },
      });
      setSignature(sig);
      setLog("Signed. Copy the signature below to the agent.");
    } catch (err) {
      setLog(`Error: ${(err as Error).message}`);
    }
  }

  return (
    <section className="border border-neutral-800 rounded-md p-4 flex flex-col gap-4 bg-neutral-950/40">
      <h2 className="text-xs font-mono uppercase tracking-widest text-neutral-500">Client Actions</h2>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-neutral-400">Agent address</span>
          <input
            value={agentAddress}
            onChange={(e) => setAgentAddress(e.target.value)}
            placeholder="0x…"
            className="rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-sm"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-neutral-400">Payment amount (payment token)</span>
          <input
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-sm"
          />
        </label>
      </div>

      <div className="flex flex-wrap gap-2">
        <button
          disabled={isPending}
          onClick={handleFund}
          className="rounded border border-emerald-700 bg-emerald-950 px-3 py-1.5 text-sm text-emerald-300 hover:bg-emerald-900 disabled:opacity-50 transition-colors"
        >
          1. Fund Task
        </button>
        <button
          disabled={isPending}
          onClick={handleSignEngagement}
          className="rounded border border-emerald-700 bg-emerald-950 px-3 py-1.5 text-sm text-emerald-300 hover:bg-emerald-900 disabled:opacity-50 transition-colors"
        >
          2. Sign TaskEngagement (EIP-712)
        </button>
      </div>

      {signature && (
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-neutral-400">Client signature — copy this to the Agent panel</span>
          <textarea
            readOnly
            value={signature}
            className="rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-xs break-all"
            rows={3}
          />
        </label>
      )}

      {log && <p className="text-xs font-mono text-neutral-500">{log}</p>}

      <p className="text-xs text-neutral-600">
        To dispute an assertion once it exists, use the dispute action in the Status panel below —
        only this client&apos;s address is authorized to dispute this requestHash.
      </p>
    </section>
  );
}
