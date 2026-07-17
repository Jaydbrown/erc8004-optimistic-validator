"use client";

import { useEffect, useState } from "react";
import { keccak256, toBytes } from "viem";

export interface TaskIdentity {
  taskLabel: string;
  setTaskLabel: (v: string) => void;
  agentId: string;
  setAgentId: (v: string) => void;
  deadlineHours: string;
  setDeadlineHours: (v: string) => void;
  requestHash: `0x${string}`;
  deadline: bigint;
}

export function useTaskIdentityValues(
  taskLabel: string,
  agentId: string,
  deadlineHours: string,
): { requestHash: `0x${string}`; deadline: bigint } {
  const requestHash = keccak256(toBytes(taskLabel || "untitled-task"));

  // Deferred to a post-mount effect (rather than computed inline) so the
  // server-rendered HTML and the client's first hydration pass agree on a
  // fixed value (0n) — Date.now() differs by render pass and would otherwise
  // cause a hydration mismatch.
  const [deadline, setDeadline] = useState<bigint>(0n);
  useEffect(() => {
    const hours = Number(deadlineHours || "1");
    // Intentional: syncing to the client's wall clock, unknowable during SSR.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setDeadline(BigInt(Math.floor(Date.now() / 1000) + Math.max(hours, 0) * 3600));
  }, [deadlineHours]);

  return { requestHash, deadline };
}

export function TaskHeader(props: TaskIdentity) {
  return (
    <section className="border border-neutral-800 rounded-md p-4 flex flex-col gap-3 bg-neutral-950/40">
      <h2 className="text-xs font-mono uppercase tracking-widest text-neutral-500">
        Current Task
      </h2>
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-neutral-400">Task label (any string — hashed client-side)</span>
          <input
            value={props.taskLabel}
            onChange={(e) => props.setTaskLabel(e.target.value)}
            className="rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-sm"
            placeholder="e.g. code-review-2026-07-17"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-neutral-400">Agent ID (ERC-8004)</span>
          <input
            value={props.agentId}
            onChange={(e) => props.setAgentId(e.target.value)}
            className="rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-sm"
          />
        </label>
        <label className="flex flex-col gap-1 text-sm">
          <span className="text-neutral-400">Engagement deadline (hours from now)</span>
          <input
            value={props.deadlineHours}
            onChange={(e) => props.setDeadlineHours(e.target.value)}
            className="rounded border border-neutral-700 bg-neutral-900 px-2 py-1.5 font-mono text-sm"
          />
        </label>
      </div>
      <div className="text-xs font-mono text-neutral-500 break-all">
        requestHash: <span className="text-emerald-400">{props.requestHash}</span>
        {"  ·  "}
        deadline (unix): <span className="text-emerald-400">{props.deadline.toString()}</span>
      </div>
    </section>
  );
}
