import http from "k6/http";
import { check, sleep } from "k6";
import { Rate } from "k6/metrics";

const errors = new Rate("errors");
const API = __ENV.API_BASE || "http://localhost:8000";

export const options = {
  stages: [
    { duration: "1m", target: 10 },
    { duration: "3m", target: 50 },
    { duration: "2m", target: 200 },
    { duration: "1m", target: 0 },
  ],
  thresholds: {
    http_req_duration: ["p(95)<400"],
    errors: ["rate<0.01"],
  },
};

export default function () {
  const health = http.get(`${API}/healthz`);
  check(health, { "healthz 200": (r) => r.status === 200 }) || errors.add(1);

  const vehicles = http.get(`${API}/vehicles`);
  check(vehicles, { "vehicles 200": (r) => r.status === 200 }) || errors.add(1);

  const eta = http.post(
    `${API}/eta`,
    JSON.stringify({
      origin: [48.86, 2.35],
      destination: [48.88, 2.30],
    }),
    { headers: { "Content-Type": "application/json" } },
  );
  check(eta, { "eta 200": (r) => r.status === 200 }) || errors.add(1);

  sleep(1);
}
