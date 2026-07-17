"use client";

import { useReadContract, useWriteContractSync } from "wagmi";
import { useEffect, useState } from "react";
import { formatUnits } from "viem";
import { contracts } from "@/lib/contracts";
import { useRole } from "@/contexts/role-context";

const TASK_STATUS = ["None", "Funded", "Settled"];
const REQUEST_STATUS = ["None", "Proposed", "Resolved"];
const ASSERTION_STATUS = ["None", "Proposed", "Resolved"];

interface Props {
  requestHash: `0x${string}`;
}

export function StatusPanel({ requestHash }: Props) {
  const { activeAddress } = useRole();
  const [log, setLog] = useState("");
  const { mutateAsync: writeAsync, isPending } = useWriteContractSync();

  const { data: task, refetch: refetchTask } = useReadContract({
    ...contracts.taskEscrow,
    functionName: "getTask",
    args: [requestHash],
    query: { refetchInterval: 4000 },
  });

  const { data: request, refetch: refetchRequest } = useReadContract({
    ...contracts.validator,
    functionName: "getRequest",
    args: [requestHash],
    query: { refetchInterval: 4000 },
  });

  const assertionId = request?.assertionId as `0x${string}` | undefined;
  const hasAssertion = !!assertionId && assertionId !== "0x" + "0".repeat(64);

  const { data: assertion, refetch: refetchAssertion } = useReadContract({
    ...contracts.bondedAssertion,
    functionName: "getAssertion",
    args: assertionId ? [assertionId] : undefined,
    query: { enabled: hasAssertion, refetchInterval: 4000 },
  });

  // Clock reads happen only inside the interval callback (never during
  // render) so this ticks live without calling an impure function from render.
  const [now, setNow] = useState<number | null>(null);
  useEffect(() => {
    const tick = () => setNow(Math.floor(Date.now() / 1000));
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, []);
  const expiresIn =
    assertion && now !== null
      ? Number(assertion.expirationTime) - now
      : undefined;

  async function refetchAll() {
    await Promise.all([refetchTask(), refetchRequest(), refetchAssertion()]);
  }

  async function handleDisputeAssertion() {
    if (!activeAddress || !assertionId) return;
    setLog("Disputing assertion…");
    try {
      await writeAsync({
        ...contracts.bondedAssertion,
        functionName: "disputeAssertion",
        args: [assertionId],
        account: activeAddress,
        throwOnReceiptRevert: true,
      });
      setLog("Disputed — resolved as not-truthful, bond paid to disputer.");
      await refetchAll();
    } catch (err) {
      setLog(
        `Error: ${(err as { shortMessage?: string; message: string }).shortMessage ?? (err as Error).message}`,
      );
    }
  }

  async function handleSettleAssertion() {
    if (!activeAddress || !assertionId) return;
    setLog("Settling assertion (liveness must have expired)…");
    try {
      await writeAsync({
        ...contracts.bondedAssertion,
        functionName: "settleAssertion",
        args: [assertionId],
        account: activeAddress,
        throwOnReceiptRevert: true,
      });
      setLog("Assertion settled as truthful — bond returned to agent.");
      await refetchAll();
    } catch (err) {
      setLog(
        `Error: ${(err as { shortMessage?: string; message: string }).shortMessage ?? (err as Error).message}`,
      );
    }
  }

  async function handleSettleEscrow() {
    if (!activeAddress) return;
    setLog("Settling escrow…");
    try {
      await writeAsync({
        ...contracts.taskEscrow,
        functionName: "settle",
        args: [requestHash],
        account: activeAddress,
        throwOnReceiptRevert: true,
      });
      setLog("Escrow settled — payment released.");
      await refetchAll();
    } catch (err) {
      setLog(
        `Error: ${(err as { shortMessage?: string; message: string }).shortMessage ?? (err as Error).message}`,
      );
    }
  }

  return (
    <section className="border border-neutral-800 rounded-md p-4 flex flex-col gap-4 bg-neutral-950/40">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <h2 className="text-xs font-mono uppercase tracking-widest text-neutral-500">
          Status — anyone may trigger settlement below
        </h2>
        <button
          onClick={() => refetchAll()}
          className="text-xs font-mono text-neutral-500 border border-neutral-800 rounded px-3 py-3 hover:bg-neutral-900"
        >
          Refresh
        </button>
      </div>

      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 text-sm">
        <div className="flex flex-col gap-1">
          <span className="text-xs font-mono uppercase text-neutral-600">
            TaskEscrow
          </span>
          <span>
            Status: <b>{task ? TASK_STATUS[task.status] : "—"}</b>
          </span>
          <span className="font-mono text-xs text-neutral-500 break-all">
            client: {task?.client ?? "—"}
          </span>
          <span className="font-mono text-xs text-neutral-500 break-all">
            agent: {task?.agent ?? "—"}
          </span>
          <span className="font-mono text-xs text-neutral-500">
            amount: {task ? `${formatUnits(task.amount, 18)} MON` : "—"}
          </span>
        </div>

        <div className="flex flex-col gap-1">
          <span className="text-xs font-mono uppercase text-neutral-600">
            Validator Request
          </span>
          <span>
            Status: <b>{request ? REQUEST_STATUS[request.status] : "—"}</b>
          </span>
          <span className="font-mono text-xs text-neutral-500 break-all">
            client: {request?.client ?? "—"}
          </span>
          <span className="font-mono text-xs text-neutral-500 break-all">
            assertionId: {hasAssertion ? assertionId : "—"}
          </span>
        </div>

        <div className="flex flex-col gap-1">
          <span className="text-xs font-mono uppercase text-neutral-600">
            Bonded Assertion
          </span>
          <span>
            Status:{" "}
            <b>{assertion ? ASSERTION_STATUS[assertion.status] : "—"}</b>
          </span>
          <span>
            Truthful: <b>{assertion ? String(assertion.truthful) : "—"}</b>
            {"  "}
            Overridden: <b>{assertion ? String(assertion.overridden) : "—"}</b>
          </span>
          <span className="font-mono text-xs text-neutral-500">
            {expiresIn !== undefined
              ? expiresIn > 0
                ? `liveness expires in ${expiresIn}s`
                : "liveness expired — settleable"
              : "—"}
          </span>
        </div>
      </div>

      <div className="flex flex-wrap gap-2 border-t border-neutral-800 pt-3">
        <button
          disabled={isPending || !hasAssertion}
          onClick={handleDisputeAssertion}
          className="rounded border border-red-800 bg-red-950 px-3 py-2.5 text-sm text-red-300 hover:bg-red-900 disabled:opacity-50 transition-colors"
        >
          Dispute Assertion (client only)
        </button>
        <button
          disabled={isPending || !hasAssertion}
          onClick={handleSettleAssertion}
          className="rounded border border-neutral-700 px-3 py-2.5 text-sm text-neutral-300 hover:bg-neutral-800 disabled:opacity-50 transition-colors"
        >
          Settle Assertion (after liveness)
        </button>
        <button
          disabled={isPending || task?.status !== 1}
          onClick={handleSettleEscrow}
          className="rounded border border-neutral-700 px-3 py-2.5 text-sm text-neutral-300 hover:bg-neutral-800 disabled:opacity-50 transition-colors"
        >
          Settle Escrow (release/refund payment)
        </button>
      </div>

      {log && <p className="text-xs font-mono text-neutral-500">{log}</p>}
    </section>
  );
}
