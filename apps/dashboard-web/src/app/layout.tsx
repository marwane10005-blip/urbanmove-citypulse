import type { Metadata } from "next";
import type { ReactNode } from "react";

export const metadata: Metadata = {
  title: "UrbanMove — Operator Dashboard",
  description: "Live fleet supervision, congestion, and ETA analytics.",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body
        style={{
          margin: 0,
          fontFamily:
            "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
          backgroundColor: "#0b1220",
          color: "#e4e8ee",
        }}
      >
        {children}
      </body>
    </html>
  );
}
