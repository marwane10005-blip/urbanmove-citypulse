type Message = {
  type: "hello" | "telemetry" | "congestion" | string;
  [key: string]: unknown;
};

const WS_URL = process.env.NEXT_PUBLIC_WS_URL ?? "";

export class AlertSocket {
  private socket: WebSocket | null = null;
  private handlers = new Set<(msg: Message) => void>();
  private reconnectDelayMs = 1000;
  private pingTimer: ReturnType<typeof setInterval> | null = null;
  private stopped = false;

  on(handler: (msg: Message) => void): () => void {
    this.handlers.add(handler);
    return () => this.handlers.delete(handler);
  }

  async start(): Promise<void> {
    if (!WS_URL) {
      console.warn("NEXT_PUBLIC_WS_URL missing — AlertSocket disabled.");
      return;
    }
    this.stopped = false;
    this.connect();
  }

  stop(): void {
    this.stopped = true;
    if (this.pingTimer) clearInterval(this.pingTimer);
    this.socket?.close();
    this.socket = null;
  }

  private connect(): void {
    this.socket = new WebSocket(WS_URL);

    this.socket.addEventListener("open", () => {
      this.reconnectDelayMs = 1000;
      this.pingTimer = setInterval(() => this.socket?.send("ping"), 30_000);
    });

    this.socket.addEventListener("message", (e) => {
      const data = e.data;
      if (data === "pong") return;
      try {
        const parsed = JSON.parse(data as string) as Message;
        this.handlers.forEach((h) => h(parsed));
      } catch {

      }
    });

    this.socket.addEventListener("close", () => {
      if (this.pingTimer) clearInterval(this.pingTimer);
      if (this.stopped) return;

      const delay = Math.min(this.reconnectDelayMs, 30_000);
      setTimeout(() => this.connect(), delay);
      this.reconnectDelayMs = Math.min(this.reconnectDelayMs * 2, 30_000);
    });
  }
}
