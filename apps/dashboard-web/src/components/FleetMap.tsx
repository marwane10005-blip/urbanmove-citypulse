"use client";

import { useEffect, useMemo, useRef, useState } from "react";
import maplibregl from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";

import { api, type Vehicle } from "@/lib/api";
import { AlertSocket } from "@/lib/ws";

const TILE_STYLE = "https://tiles.openfreemap.org/styles/bright";

const PARIS_CENTER: [number, number] = [2.3522, 48.8566];

type CongestionEvent = {
  id: string;
  zone: string;
  avg_speed_kmh: number;
  severity: number;
  ts: number;
};

export function FleetMap() {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const mapRef = useRef<maplibregl.Map | null>(null);
  const markersRef = useRef<Map<string, maplibregl.Marker>>(new Map());
  const [vehicles, setVehicles] = useState<Record<string, Vehicle>>({});
  const [toasts, setToasts] = useState<CongestionEvent[]>([]);
  const [wsStatus, setWsStatus] = useState<"connecting" | "live" | "offline">(
    "connecting",
  );

  useEffect(() => {
    if (!containerRef.current) return;
    const map = new maplibregl.Map({
      container: containerRef.current,
      style: TILE_STYLE,
      center: PARIS_CENTER,
      zoom: 12.5,
    });
    map.addControl(new maplibregl.NavigationControl({}), "top-right");
    mapRef.current = map;
    return () => {
      map.remove();
      mapRef.current = null;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;
    const tick = async () => {
      try {
        const list = await api.listVehicles();
        if (cancelled) return;
        const indexed = Object.fromEntries(list.map((v) => [v.vehicle_id, v]));
        setVehicles(indexed);
      } catch (err) {
        console.error("fetch vehicles failed", err);
      }
    };
    tick();
    const interval = setInterval(tick, 3000);
    return () => {
      cancelled = true;
      clearInterval(interval);
    };
  }, []);

  useEffect(() => {
    const ws = new AlertSocket();
    const unsubscribe = ws.on((msg) => {
      if (msg.type === "hello") {
        setWsStatus("live");
        return;
      }
      if (msg.type === "telemetry" && typeof msg.vehicle_id === "string") {
        const v = msg as unknown as Vehicle;
        setVehicles((prev) => ({ ...prev, [v.vehicle_id]: v }));
        return;
      }
      if (msg.type === "congestion") {
        const ev: CongestionEvent = {
          id: `${(msg.zone as string) ?? "unknown"}-${Date.now()}`,
          zone: (msg.zone as string) ?? "unknown",
          avg_speed_kmh: Number(msg.avg_speed_kmh ?? 0),
          severity: Number(msg.severity ?? 1),
          ts: Number(msg.ts ?? Date.now() / 1000),
        };
        setToasts((prev) => [...prev, ev].slice(-5));

        setTimeout(() => {
          setToasts((prev) => prev.filter((t) => t.id !== ev.id));
        }, 12_000);
      }
    });
    void ws.start();
    return () => {
      unsubscribe();
      ws.stop();
    };
  }, []);

  useEffect(() => {
    const map = mapRef.current;
    if (!map) return;
    const live = new Set<string>();
    for (const v of Object.values(vehicles)) {
      if (v.lat == null || v.lon == null) continue;
      live.add(v.vehicle_id);
      const existing = markersRef.current.get(v.vehicle_id);
      const lngLat: [number, number] = [v.lon, v.lat];
      if (existing) {
        existing.setLngLat(lngLat);
      } else {
        const el = document.createElement("div");
        el.style.cssText =
          "width:10px;height:10px;border-radius:50%;background:#50c878;border:2px solid #0b1220;";
        const marker = new maplibregl.Marker({ element: el })
          .setLngLat(lngLat)
          .setPopup(
            new maplibregl.Popup({ offset: 12, className: "urbanmove-popup" }).setHTML(
              `<div style="color:#0b1220;font-family:-apple-system,BlinkMacSystemFont,sans-serif;line-height:1.4;">
                <div style="font-weight:600;font-size:0.95rem;">${v.vehicle_id}</div>
                <div style="font-size:0.85rem;color:#374151;">
                  ${v.speed_kmh?.toFixed(1) ?? "?"} km/h · battery ${v.battery_pct?.toFixed(0) ?? "?"}%
                </div>
              </div>`,
            ),
          )
          .addTo(map);
        markersRef.current.set(v.vehicle_id, marker);
      }
    }

    for (const [id, marker] of markersRef.current.entries()) {
      if (!live.has(id)) {
        marker.remove();
        markersRef.current.delete(id);
      }
    }
  }, [vehicles]);

  const activeCount = useMemo(
    () =>
      Object.values(vehicles).filter((v) => v.lat != null && v.lon != null).length,
    [vehicles],
  );

  return (
    <div
      style={{ display: "flex", flexDirection: "column", gap: "0.5rem", position: "relative" }}
    >
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div>
          <strong>{activeCount}</strong> active vehicles
        </div>
        <div style={{ display: "flex", gap: "0.5rem", alignItems: "center" }}>
          <span
            style={{
              fontSize: "0.75rem",
              padding: "0.15rem 0.45rem",
              borderRadius: 999,
              background:
                wsStatus === "live"
                  ? "rgba(80, 200, 120, 0.18)"
                  : wsStatus === "offline"
                    ? "rgba(240, 70, 70, 0.18)"
                    : "rgba(120, 130, 180, 0.18)",
              color:
                wsStatus === "live"
                  ? "#74e09a"
                  : wsStatus === "offline"
                    ? "#ff8a8a"
                    : "#a8b1d6",
            }}
          >
            ● ws {wsStatus}
          </span>
        </div>
      </div>

      <div
        ref={containerRef}
        style={{ width: "100%", height: "60vh", borderRadius: 8, overflow: "hidden" }}
      />

      {}
      <div
        style={{
          position: "fixed",
          top: 80,
          right: 24,
          display: "flex",
          flexDirection: "column",
          gap: "0.5rem",
          zIndex: 1000,
          pointerEvents: "none",
        }}
      >
        {toasts.map((t) => (
          <div
            key={t.id}
            style={{
              minWidth: 280,
              padding: "0.75rem 1rem",
              background: severityBg(t.severity),
              color: "#ffffff",
              border: "1px solid rgba(255,255,255,0.2)",
              borderRadius: 8,
              boxShadow: "0 8px 24px rgba(0,0,0,0.35)",
              animation: "umt-slide-in 0.25s ease-out",
            }}
          >
            <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <span style={{ fontSize: "1.1rem" }}>⚠</span>
              <strong>Congestion detected</strong>
              <span
                style={{
                  marginLeft: "auto",
                  fontSize: "0.7rem",
                  opacity: 0.8,
                  background: "rgba(0,0,0,0.18)",
                  padding: "0.1rem 0.4rem",
                  borderRadius: 999,
                }}
              >
                sev {t.severity}/5
              </span>
            </div>
            <div style={{ marginTop: "0.25rem", fontSize: "0.85rem", opacity: 0.95 }}>
              Zone <code style={{ opacity: 0.9 }}>{t.zone}</code> · avg {t.avg_speed_kmh.toFixed(1)}{" "}
              km/h
            </div>
          </div>
        ))}
      </div>

      {}
      <style>{`
        @keyframes umt-slide-in {
          from { transform: translateX(20px); opacity: 0; }
          to   { transform: translateX(0);    opacity: 1; }
        }
        .urbanmove-popup .maplibregl-popup-content {
          padding: 0.6rem 0.85rem;
          border-radius: 8px;
          background: #ffffff;
        }
        .urbanmove-popup .maplibregl-popup-tip { border-top-color: #ffffff; }
      `}</style>
    </div>
  );
}

function severityBg(sev: number): string {

  if (sev >= 4) return "rgba(220, 60, 60, 0.95)";
  if (sev === 3) return "rgba(240, 140, 40, 0.95)";
  return "rgba(190, 150, 40, 0.95)";
}
