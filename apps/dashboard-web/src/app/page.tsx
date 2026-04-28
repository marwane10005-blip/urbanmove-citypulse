"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { fetchAuthSession, signOut } from "aws-amplify/auth";

import { configureAmplify } from "@/lib/amplify";
import { FleetMap } from "@/components/FleetMap";
import { EtaPanel } from "@/components/EtaPanel";

export default function HomePage() {
  const router = useRouter();
  const [email, setEmail] = useState<string | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    configureAmplify();
    (async () => {
      try {
        const session = await fetchAuthSession();
        const claims = session.tokens?.idToken?.payload as Record<string, unknown> | undefined;
        const userEmail = typeof claims?.email === "string" ? claims.email : null;
        if (!userEmail) {
          router.replace("/login");
          return;
        }
        setEmail(userEmail);
      } catch {
        router.replace("/login");
        return;
      } finally {
        setReady(true);
      }
    })();
  }, [router]);

  if (!ready) {
    return <main style={{ padding: "2rem" }}>Loading…</main>;
  }

  return (
    <main style={{ padding: "2rem", maxWidth: 1200, margin: "0 auto" }}>
      <header
        style={{
          marginBottom: "1.5rem",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
        }}
      >
        <div>
          <h1 style={{ margin: 0, fontSize: "1.75rem" }}>UrbanMove</h1>
          <p style={{ margin: "0.25rem 0 0", opacity: 0.7 }}>
            Operator dashboard · Paris fleet · {new Date().toISOString().slice(0, 10)}
          </p>
        </div>
        <div style={{ textAlign: "right" }}>
          <div style={{ fontSize: "0.85rem", opacity: 0.7 }}>{email}</div>
          <button
            onClick={async () => {
              await signOut();
              router.push("/login");
            }}
            style={{
              marginTop: "0.25rem",
              padding: "0.35rem 0.6rem",
              border: "1px solid #243049",
              borderRadius: 6,
              background: "transparent",
              color: "#e4e8ee",
              cursor: "pointer",
              fontSize: "0.85rem",
            }}
          >
            Sign out
          </button>
        </div>
      </header>

      <FleetMap />

      <section style={{ marginTop: "1.5rem" }}>
        <EtaPanel />
      </section>
    </main>
  );
}
