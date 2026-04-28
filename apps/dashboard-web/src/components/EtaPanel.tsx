"use client";

import { FormEvent, useState } from "react";

import { api, type EtaResponse } from "@/lib/api";

const DEFAULTS = {
  originLat: 48.8606,
  originLon: 2.3376,
  destLat: 48.8867,
  destLon: 2.3431,
  hourOfDay: 18,
  dayOfWeek: 1,
  congestion: 0.6,
};

export function EtaPanel() {
  const [originLat, setOriginLat] = useState<number>(DEFAULTS.originLat);
  const [originLon, setOriginLon] = useState<number>(DEFAULTS.originLon);
  const [destLat, setDestLat] = useState<number>(DEFAULTS.destLat);
  const [destLon, setDestLon] = useState<number>(DEFAULTS.destLon);
  const [hourOfDay, setHourOfDay] = useState<number>(DEFAULTS.hourOfDay);
  const [dayOfWeek, setDayOfWeek] = useState<number>(DEFAULTS.dayOfWeek);
  const [congestion, setCongestion] = useState<number>(DEFAULTS.congestion);

  const [result, setResult] = useState<EtaResponse | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [latencyMs, setLatencyMs] = useState<number | null>(null);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    setLatencyMs(null);
    const start = performance.now();
    try {
      const r = await api.predictEta({
        origin: [originLat, originLon],
        destination: [destLat, destLon],
        hour_of_day: hourOfDay,
        day_of_week: dayOfWeek,
        zone_congestion_index: congestion,
      });
      setResult(r);
      setLatencyMs(Math.round(performance.now() - start));
    } catch (err) {
      setError(err instanceof Error ? err.message : "request failed");
      setResult(null);
    } finally {
      setLoading(false);
    }
  };

  const fmtSeconds = (s: number) => {
    const m = Math.floor(s / 60);
    const sec = Math.round(s % 60);
    return m > 0 ? `${m} min ${sec}s` : `${sec}s`;
  };

  return (
    <form
      onSubmit={submit}
      style={{
        border: "1px solid #243049",
        borderRadius: 8,
        padding: "1rem 1.1rem",
        display: "grid",
        gridTemplateColumns: "1fr 1fr",
        gap: "0.5rem 0.75rem",
        background: "#0f172a",
      }}
    >
      <div style={{ gridColumn: "1 / -1", display: "flex", alignItems: "baseline", gap: "0.5rem" }}>
        <h3 style={{ margin: 0, fontSize: "1rem" }}>ETA prediction</h3>
        <span style={{ fontSize: "0.75rem", opacity: 0.6 }}>
          /eta on mobility-api → SageMaker (or haversine fallback)
        </span>
      </div>

      <CoordField label="Origin lat" value={originLat} onChange={setOriginLat} step={0.0001} />
      <CoordField label="Origin lon" value={originLon} onChange={setOriginLon} step={0.0001} />
      <CoordField label="Dest lat" value={destLat} onChange={setDestLat} step={0.0001} />
      <CoordField label="Dest lon" value={destLon} onChange={setDestLon} step={0.0001} />
      <CoordField
        label="Hour of day"
        value={hourOfDay}
        onChange={setHourOfDay}
        step={1}
        min={0}
        max={23}
      />
      <CoordField
        label="Day of week (0=Mon)"
        value={dayOfWeek}
        onChange={setDayOfWeek}
        step={1}
        min={0}
        max={6}
      />
      <CoordField
        label="Zone congestion (0–1)"
        value={congestion}
        onChange={setCongestion}
        step={0.05}
        min={0}
        max={1}
      />

      <button
        type="submit"
        disabled={loading}
        style={{
          gridColumn: "1 / -1",
          marginTop: "0.25rem",
          padding: "0.55rem 0.8rem",
          border: 0,
          borderRadius: 6,
          background: loading ? "#334" : "#4466ee",
          color: "#fff",
          fontWeight: 600,
          cursor: loading ? "wait" : "pointer",
        }}
      >
        {loading ? "Predicting…" : "Predict ETA"}
      </button>

      {error && (
        <div
          role="alert"
          style={{
            gridColumn: "1 / -1",
            padding: "0.5rem 0.65rem",
            borderRadius: 6,
            background: "rgba(240, 70, 70, 0.15)",
            color: "#ff9090",
            fontSize: "0.85rem",
          }}
        >
          {error}
        </div>
      )}

      {result && (
        <div
          style={{
            gridColumn: "1 / -1",
            padding: "0.7rem 0.85rem",
            borderRadius: 6,
            background: "rgba(80, 200, 120, 0.10)",
            border: "1px solid rgba(80, 200, 120, 0.35)",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
            <strong style={{ fontSize: "1.25rem", color: "#74e09a" }}>
              {fmtSeconds(result.eta_seconds)}
            </strong>
            <SourceBadge source={result.source} />
            {latencyMs != null && (
              <span style={{ marginLeft: "auto", fontSize: "0.7rem", opacity: 0.7 }}>
                {latencyMs} ms round-trip
              </span>
            )}
          </div>
          <div style={{ marginTop: "0.25rem", fontSize: "0.8rem", opacity: 0.75 }}>
            distance {result.distance_m.toFixed(0)} m · raw {result.eta_seconds.toFixed(1)} s
          </div>
        </div>
      )}
    </form>
  );
}

function SourceBadge({ source }: { source: "model" | "fallback" }) {
  const colors =
    source === "model"
      ? { bg: "rgba(80, 200, 120, 0.25)", fg: "#74e09a", label: "● model" }
      : { bg: "rgba(240, 140, 40, 0.25)", fg: "#ffb878", label: "● fallback" };
  return (
    <span
      style={{
        fontSize: "0.7rem",
        padding: "0.15rem 0.5rem",
        borderRadius: 999,
        background: colors.bg,
        color: colors.fg,
      }}
    >
      {colors.label}
    </span>
  );
}

function CoordField({
  label,
  value,
  onChange,
  step,
  min,
  max,
}: {
  label: string;
  value: number;
  onChange: (v: number) => void;
  step: number;
  min?: number;
  max?: number;
}) {
  return (
    <label style={{ display: "flex", flexDirection: "column", gap: "0.2rem" }}>
      <span style={{ fontSize: "0.7rem", opacity: 0.65 }}>{label}</span>
      <input
        type="number"
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        step={step}
        min={min}
        max={max}
        style={{
          padding: "0.4rem 0.55rem",
          border: "1px solid #243049",
          borderRadius: 5,
          background: "#0b1220",
          color: "#e4e8ee",
          fontSize: "0.88rem",
        }}
      />
    </label>
  );
}
