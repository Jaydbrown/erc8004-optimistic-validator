"use client";

import { useState } from "react";
import { ConnectBar } from "@/components/connect-bar";
import { TaskHeader, useTaskIdentityValues } from "@/components/task-header";
import { ClientPanel } from "@/components/client-panel";
import { AgentPanel } from "@/components/agent-panel";
import { CouncilPanel } from "@/components/council-panel";
import { StatusPanel } from "@/components/status-panel";
import { useRole } from "@/contexts/role-context";

export default function Home() {
  const { role } = useRole();
  const [taskLabel, setTaskLabel] = useState("demo-task");
  const [agentId, setAgentId] = useState("1");
  const [deadlineHours, setDeadlineHours] = useState("1");

  const { requestHash, deadline } = useTaskIdentityValues(taskLabel, agentId, deadlineHours);

  return (
    <div className="flex flex-col min-h-screen bg-neutral-950 text-neutral-100">
      <ConnectBar />
      <main className="flex-1 max-w-5xl w-full mx-auto px-6 py-8 flex flex-col gap-6">
        <TaskHeader
          taskLabel={taskLabel}
          setTaskLabel={setTaskLabel}
          agentId={agentId}
          setAgentId={setAgentId}
          deadlineHours={deadlineHours}
          setDeadlineHours={setDeadlineHours}
          requestHash={requestHash}
          deadline={deadline}
        />

        {role === "client" && (
          <ClientPanel requestHash={requestHash} agentId={agentId} deadline={deadline} />
        )}
        {role === "agent" && (
          <AgentPanel requestHash={requestHash} agentId={agentId} deadline={deadline} />
        )}
        {role === "council" && <CouncilPanel />}

        <StatusPanel requestHash={requestHash} />
      </main>
      <footer className="border-t border-neutral-800 px-6 py-4 text-xs font-mono text-neutral-600">
        Local dev chain — connect the &quot;Local Dev Wallet&quot; to sign as any of Anvil&apos;s
        well-known default accounts. Never use those keys on a real chain.
      </footer>
    </div>
  );
}
