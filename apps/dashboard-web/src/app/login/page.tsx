"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { signIn, signOut } from "aws-amplify/auth";

import { configureAmplify } from "@/lib/amplify";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    configureAmplify();
  }, []);

  const onSubmit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      await signOut().catch(() => undefined);
      const { isSignedIn, nextStep } = await signIn({
        username: email,
        password,
      });
      if (isSignedIn) {
        router.push("/");
      } else {
        setError(`Additional step required: ${nextStep.signInStep}`);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign-in failed");
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <main
      style={{
        minHeight: "100vh",
        display: "grid",
        placeItems: "center",
        padding: "2rem",
      }}
    >
      <form
        onSubmit={onSubmit}
        style={{
          width: "100%",
          maxWidth: 360,
          display: "flex",
          flexDirection: "column",
          gap: "0.75rem",
          padding: "2rem",
          border: "1px solid #243049",
          borderRadius: 8,
        }}
      >
        <h1 style={{ margin: 0, fontSize: "1.5rem" }}>UrbanMove operator sign-in</h1>
        <label style={{ display: "flex", flexDirection: "column", gap: "0.25rem" }}>
          <span style={{ fontSize: "0.85rem", opacity: 0.7 }}>email</span>
          <input
            type="email"
            required
            autoComplete="username"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            style={inputStyle}
          />
        </label>
        <label style={{ display: "flex", flexDirection: "column", gap: "0.25rem" }}>
          <span style={{ fontSize: "0.85rem", opacity: 0.7 }}>password</span>
          <input
            type="password"
            required
            autoComplete="current-password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            style={inputStyle}
          />
        </label>
        {error && (
          <div
            role="alert"
            style={{
              padding: "0.5rem 0.75rem",
              borderRadius: 6,
              background: "rgba(240, 70, 70, 0.15)",
              color: "#ff9090",
              fontSize: "0.85rem",
            }}
          >
            {error}
          </div>
        )}
        <button type="submit" disabled={submitting} style={buttonStyle}>
          {submitting ? "Signing in…" : "Sign in"}
        </button>
      </form>
    </main>
  );
}

const inputStyle: React.CSSProperties = {
  padding: "0.55rem 0.65rem",
  border: "1px solid #243049",
  borderRadius: 6,
  background: "#0f172a",
  color: "#e4e8ee",
  fontSize: "0.95rem",
};

const buttonStyle: React.CSSProperties = {
  marginTop: "0.5rem",
  padding: "0.6rem 0.75rem",
  border: 0,
  borderRadius: 6,
  background: "#4466ee",
  color: "#ffffff",
  fontWeight: 600,
  cursor: "pointer",
  opacity: 1,
};
