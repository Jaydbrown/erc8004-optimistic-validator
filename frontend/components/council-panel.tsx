"use client";

import { useState } from "react";
import { useWriteContractSync } from "wagmi";
import { contracts } from "@/lib/contracts";
import { useRole } from "@/contexts/role-context";

export function CouncilPanel() {
  const { activeAddress } = useRole();
  const [assertionId, setAssertionId] = useState("");
  const [log, setLog] = useState("");
  const { mutateAsync: writeAsync, isPending } = useWriteContractSync();

  async function resolve(truthful: boolean) {
    if (!activeAddress || !assertionId) return;
    setLog(
      `Resolving override as ${truthful ? "truthful (agent wins)" : "not truthful (client wins)"}…`,
    );
    try {
      await writeAsync({
        ...contracts.escalationManager,
        functionName: "resolveOverride",
        args: [assertionId as `0x${string}`, truthful],
        account: activeAddress,
        throwOnReceiptRevert: true,
      });
      setLog(
        "Override resolved. The ERC-8004 validation response has been corrected.",
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
        Arbitration Council Actions
      </h2>
      <p className="text-xs text-neutral-600">
        Only usable after the agent has raised a counter-dispute on this
        assertion. This is the rare, explicitly-centralized backstop path — not
        the common resolution path.
      </p>
      <label className="flex flex-col gap-1 text-sm">
        <span className="text-neutral-400">Assertion ID</span>
        <input
          value={assertionId}
          onChange={(e) => setAssertionId(e.target.value)}
          placeholder="0x… (see Status panel)"
          className="w-full rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-xs"
        />
      </label>
      <div className="flex flex-wrap gap-2">
        <button
          disabled={isPending}
          onClick={() => resolve(true)}
          className="rounded border border-emerald-700 bg-emerald-950 px-3 py-2.5 text-sm text-emerald-300 hover:bg-emerald-900 disabled:opacity-50 transition-colors"
        >
          Override → Agent was right
        </button>
        <button
          disabled={isPending}
          onClick={() => resolve(false)}
          className="rounded border border-red-800 bg-red-950 px-3 py-2.5 text-sm text-red-300 hover:bg-red-900 disabled:opacity-50 transition-colors"
        >
          Override → Client was right
        </button>
      </div>
      {log && <p className="text-xs font-mono text-neutral-500">{log}</p>}
    </section>
  );
}
