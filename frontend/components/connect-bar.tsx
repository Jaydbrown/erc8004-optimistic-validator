"use client";

import { useAccount, useConnect, useDisconnect } from "wagmi";
import { useRole } from "@/contexts/role-context";
import { ROLE_LABELS, type Role } from "@/lib/demo-accounts";

export function ConnectBar() {
  const { address, isConnected, connector } = useAccount();
  const { connect, connectors } = useConnect();
  const { disconnect } = useDisconnect();
  const { role, setRole, activeAddress, isMockConnector } = useRole();

  const mockConnector = connectors.find((c) => c.id === "mock");
  const injectedConnector = connectors.find((c) => c.id === "injected");

  return (
    <div className="w-full border-b border-neutral-800 bg-neutral-950/60 px-6 py-4 flex flex-col gap-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <span className="text-xs font-mono uppercase tracking-widest text-emerald-400">
            ERC-8004 Optimistic Validator
          </span>
        </div>

        {!isConnected ? (
          <div className="flex gap-2">
            <button
              onClick={() => mockConnector && connect({ connector: mockConnector })}
              className="rounded border border-emerald-700 bg-emerald-950 px-3 py-1.5 text-sm text-emerald-300 hover:bg-emerald-900 transition-colors"
            >
              Connect Local Dev Wallet (Anvil)
            </button>
            <button
              onClick={() => injectedConnector && connect({ connector: injectedConnector })}
              className="rounded border border-neutral-700 px-3 py-1.5 text-sm text-neutral-300 hover:bg-neutral-800 transition-colors"
            >
              Connect Wallet
            </button>
          </div>
        ) : (
          <div className="flex items-center gap-3 text-sm">
            <span className="font-mono text-neutral-400">
              {connector?.name} · {address?.slice(0, 6)}…{address?.slice(-4)}
            </span>
            <button
              onClick={() => disconnect()}
              className="rounded border border-neutral-700 px-2 py-1 text-xs text-neutral-400 hover:bg-neutral-800 transition-colors"
            >
              Disconnect
            </button>
          </div>
        )}
      </div>

      <div className="flex flex-wrap items-center gap-2">
        <span className="text-xs font-mono uppercase tracking-widest text-neutral-500 mr-1">
          Acting as:
        </span>
        {(Object.keys(ROLE_LABELS) as Role[]).map((r) => (
          <button
            key={r}
            onClick={() => setRole(r)}
            className={`rounded-sm px-3 py-1 text-sm border transition-colors ${
              role === r
                ? "border-emerald-500 bg-emerald-950 text-emerald-300"
                : "border-neutral-800 text-neutral-400 hover:border-neutral-600"
            }`}
          >
            {ROLE_LABELS[r]}
          </button>
        ))}
        {isConnected && (
          <span className="ml-2 text-xs font-mono text-neutral-500">
            {isMockConnector
              ? `signing as demo "${role}" address ${activeAddress?.slice(0, 6)}…${activeAddress?.slice(-4)}`
              : `signing as connected address ${activeAddress?.slice(0, 6)}…${activeAddress?.slice(-4)}`}
          </span>
        )}
      </div>
    </div>
  );
}
