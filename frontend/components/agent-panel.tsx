"use client";

import { useState } from "react";
import { parseUnits } from "viem";
import { useWriteContractSync } from "wagmi";
import { contracts } from "@/lib/contracts";
import { useRole } from "@/contexts/role-context";

interface Props {
  requestHash: `0x${string}`;
  agentId: string;
  deadline: bigint;
}

export function AgentPanel({ requestHash, agentId, deadline }: Props) {
  const { activeAddress } = useRole();
  const [clientAddress, setClientAddress] = useState("");
  const [clientSig, setClientSig] = useState("");
  const [responseURI, setResponseURI] = useState("ipfs://demo-evidence");
  const [bond, setBond] = useState("1000");
  const [assertionId, setAssertionId] = useState<string>("");
  const [evidenceURI, setEvidenceURI] = useState("ipfs://counter-evidence");
  const [log, setLog] = useState("");

  const { mutateAsync: writeAsync, isPending } = useWriteContractSync();

  async function handleRegisterRequest() {
    if (!activeAddress) return;
    setLog("Registering request with the ValidationRegistry…");
    try {
      await writeAsync({
        ...contracts.validationRegistry,
        functionName: "validationRequest",
        args: [
          contracts.validator.address,
          BigInt(agentId || "0"),
          "ipfs://demo-request",
          requestHash,
        ],
        account: activeAddress,
        throwOnReceiptRevert: true,
      });
      setLog("Registered. Now propose the outcome.");
    } catch (err) {
      setLog(
        `Error: ${(err as { shortMessage?: string; message: string }).shortMessage ?? (err as Error).message}`,
      );
    }
  }

  async function handlePropose() {
    if (!activeAddress || !clientAddress || !clientSig) return;
    setLog("Approving MON…");
    try {
      const bondWei = parseUnits(bond || "0", 18);
      await writeAsync({
        ...contracts.monToken,
        functionName: "approve",
        args: [contracts.validator.address, bondWei],
        account: activeAddress,
        throwOnReceiptRevert: true,
      });

      setLog("Proposing outcome…");
      const receipt = await writeAsync({
        ...contracts.validator,
        functionName: "proposeOutcome",
        args: [
          BigInt(agentId || "0"),
          requestHash,
          clientAddress as `0x${string}`,
          deadline,
          clientSig as `0x${string}`,
          responseURI,
          bondWei,
        ],
        account: activeAddress,
        throwOnReceiptRevert: true,
      });
      setLog(`Outcome proposed. Tx: ${receipt.transactionHash}`);
    } catch (err) {
      setLog(
        `Error: ${(err as { shortMessage?: string; message: string }).shortMessage ?? (err as Error).message}`,
      );
    }
  }

  async function handleCounterDispute() {
    if (!activeAddress || !assertionId) return;
    setLog("Raising counter-dispute…");
    try {
      await writeAsync({
        ...contracts.escalationManager,
        functionName: "counterDispute",
        args: [assertionId as `0x${string}`, evidenceURI],
        account: activeAddress,
        throwOnReceiptRevert: true,
      });
      setLog(
        "Counter-dispute raised — the arbitration council can now resolve it.",
      );
    } catch (err) {
      setLog(
        `Error: ${(err as { shortMessage?: string; message: string }).shortMessage ?? (err as Error).message}`,
      );
    }
  }

  return (
    <section className="border border-neutral-800 rounded-md p-4 flex flex-col gap-4 bg-neutral-950/40">
      <h2 className="text-xs font-mono uppercase tracking-widest text-neutral-500">
        Agent Actions
      </h2>

      <button
        disabled={isPending}
        onClick={handleRegisterRequest}
        className="self-start rounded border border-emerald-700 bg-emerald-950 px-3 py-2.5 text-sm text-emerald-300 hover:bg-emerald-900 disabled:opacity-50 transition-colors"
      >
        1. Register request with ValidationRegistry
      </button>

      <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-neutral-400">
            Client address (bound signer)
          </span>
          <input
            value={clientAddress}
            onChange={(e) => setClientAddress(e.target.value)}
            placeholder="0x…"
            className="w-full rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-sm"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-neutral-400">Bond amount (MON)</span>
          <input
            value={bond}
            onChange={(e) => setBond(e.target.value)}
            className="w-full rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-sm"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm sm:col-span-2">
          <span className="text-neutral-400">
            Client signature (pasted from Client panel)
          </span>
          <textarea
            value={clientSig}
            onChange={(e) => setClientSig(e.target.value)}
            rows={2}
            className="w-full rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-xs break-all resize-y"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm sm:col-span-2">
          <span className="text-neutral-400">Response evidence URI</span>
          <input
            value={responseURI}
            onChange={(e) => setResponseURI(e.target.value)}
            className="w-full rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-sm"
          />
        </label>
      </div>

      <button
        disabled={isPending}
        onClick={handlePropose}
        className="self-start rounded border border-emerald-700 bg-emerald-950 px-3 py-2.5 text-sm text-emerald-300 hover:bg-emerald-900 disabled:opacity-50 transition-colors"
      >
        2. Propose Outcome (bonds and asserts)
      </button>

      <div className="border-t border-neutral-800 pt-3 flex flex-col gap-2">
        <p className="text-xs text-neutral-600">
          If the client disputed in bad faith, raise a counter-dispute (only the
          original agent may do this) — the arbitration council can then
          override the resolution.
        </p>
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <label className="flex flex-col gap-1 text-sm">
            <span className="text-neutral-400">Assertion ID</span>
            <input
              value={assertionId}
              onChange={(e) => setAssertionId(e.target.value)}
              placeholder="0x… (see Status panel)"
              className="w-full rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-xs"
            />
          </label>
          <label className="flex flex-col gap-1 text-sm">
            <span className="text-neutral-400">Evidence URI</span>
            <input
              value={evidenceURI}
              onChange={(e) => setEvidenceURI(e.target.value)}
              className="w-full rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-sm"
            />
          </label>
        </div>
        <button
          disabled={isPending}
          onClick={handleCounterDispute}
          className="self-start rounded border border-amber-700 bg-amber-950 px-3 py-2.5 text-sm text-amber-300 hover:bg-amber-900 disabled:opacity-50 transition-colors"
        >
          Raise Counter-Dispute
        </button>
      </div>

      {log && <p className="text-xs font-mono text-neutral-500">{log}</p>}
    </section>
  );
}
