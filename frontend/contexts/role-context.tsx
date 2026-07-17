"use client";

import { createContext, useContext, useState, type ReactNode } from "react";
import { useAccount } from "wagmi";
import { DEMO_ACCOUNTS, type Role } from "@/lib/demo-accounts";

interface RoleContextValue {
  role: Role;
  setRole: (role: Role) => void;
  /** The address that should sign/send for the current role. Under the
   * local-dev mock connector this is the well-known demo address for the
   * selected role (Anvil signs for it directly); under a real wallet
   * connector it's just whatever address is actually connected. */
  activeAddress: `0x${string}` | undefined;
  isMockConnector: boolean;
}

const RoleContext = createContext<RoleContextValue | null>(null);

export function RoleProvider({ children }: { children: ReactNode }) {
  const [role, setRole] = useState<Role>("client");
  const { connector, address } = useAccount();
  const isMockConnector = connector?.id === "mock";
  const activeAddress = isMockConnector ? DEMO_ACCOUNTS[role] : address;

  return (
    <RoleContext.Provider value={{ role, setRole, activeAddress, isMockConnector }}>
      {children}
    </RoleContext.Provider>
  );
}

export function useRole() {
  const ctx = useContext(RoleContext);
  if (!ctx) throw new Error("useRole must be used within RoleProvider");
  return ctx;
}
