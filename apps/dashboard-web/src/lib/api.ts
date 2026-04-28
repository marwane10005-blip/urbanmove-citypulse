import { fetchAuthSession } from "aws-amplify/auth";

const API_BASE = process.env.NEXT_PUBLIC_API_BASE ?? "";

async function authHeader(): Promise<HeadersInit> {
  try {
    const session = await fetchAuthSession();
    const token = session.tokens?.accessToken?.toString();
    return token ? { Authorization: `Bearer ${token}` } : {};
  } catch {
    return {};
  }
}

async function request<T>(
  path: string,
  init: RequestInit = {},
): Promise<T> {
  const headers = {
    "Content-Type": "application/json",
    ...(await authHeader()),
    ...(init.headers ?? {}),
  };
  const res = await fetch(`${API_BASE}${path}`, { ...init, headers });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`${res.status} ${res.statusText}: ${body}`);
  }
  return (await res.json()) as T;
}

export interface Vehicle {
  vehicle_id: string;
  fleet_id: string;
  model: string | null;
  lat: number | null;
  lon: number | null;
  speed_kmh: number | null;
  battery_pct: number | null;
  last_seen: string | null;
}

export interface EtaRequest {
  origin: [number, number];
  destination: [number, number];
  hour_of_day?: number;
  day_of_week?: number;
  zone_congestion_index?: number;
}

export interface EtaResponse {
  eta_seconds: number;
  source: "model" | "fallback";
  distance_m: number;
}

export const api = {
  listVehicles: (fleetId?: string) =>
    request<Vehicle[]>(
      `/vehicles${fleetId ? `?fleet_id=${encodeURIComponent(fleetId)}` : ""}`,
    ),
  getVehicle: (id: string) => request<Vehicle>(`/vehicles/${encodeURIComponent(id)}`),
  predictEta: (body: EtaRequest) =>
    request<EtaResponse>("/eta", {
      method: "POST",
      body: JSON.stringify(body),
    }),
};
