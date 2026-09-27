/**
 * Realtime hub (Durable Object, WebSocket hibernation API).
 *
 * One instance per audience, named by the Worker:
 *   user:<customerId>   a customer's own devices
 *   tenant:<tenantId>   every signed-in staff member of one insurer (assessor, manager, insurer admin)
 *   platform            platform operators (superadmin)
 *
 * The hub only relays small change notices ({type, ids, status}); it never holds or sends personal data
 * or business records. Clients react by re-fetching through the normal, authorised REST routes, so
 * every permission check stays in one place. Each socket is tagged with its user id so a revoked
 * account's live connections can be closed at once.
 *
 * Internal paths (reachable only through the namespace binding, never from the internet):
 *   /connect  WebSocket upgrade, header X-EC-User carries the verified user id
 *   /publish  POST {event, closeUser?}: broadcast, or notify + close one user's sockets
 */
import type { Bindings } from '../types'

export class RealtimeHub {
  constructor(
    private readonly state: DurableObjectState,
    _env: Bindings
  ) {}

  async fetch(request: Request): Promise<Response> {
    const path = new URL(request.url).pathname
    if (path === '/connect') {
      if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') return new Response('expected websocket', { status: 426 })
      const user = request.headers.get('X-EC-User') ?? 'unknown'
      const pair = new WebSocketPair()
      const [client, server] = [pair[0], pair[1]]
      // Hibernation: the object can sleep while sockets stay open; no timers, no per-socket state.
      this.state.acceptWebSocket(server, [`user:${user}`])
      server.send(JSON.stringify({ type: 'hello', at: new Date().toISOString() }))
      return new Response(null, { status: 101, webSocket: client })
    }
    if (path === '/publish' && request.method === 'POST') {
      const { event, closeUser } = (await request.json()) as { event: Record<string, unknown>; closeUser?: string }
      const sockets = closeUser ? this.state.getWebSockets(`user:${closeUser}`) : this.state.getWebSockets()
      const message = JSON.stringify(event)
      for (const ws of sockets) {
        try {
          ws.send(message)
          if (closeUser) ws.close(4001, 'session_revoked')
        } catch {
          // A socket that is already closing is simply skipped.
        }
      }
      return new Response(null, { status: 204 })
    }
    return new Response('not found', { status: 404 })
  }

  // Clients send "ping" as a keep-alive; anything else is ignored (the channel is server → client only).
  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    if (message === 'ping') ws.send('pong')
  }

  async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    try {
      ws.close(code === 1005 ? 1000 : code, 'closed')
    } catch {
      // already closed
    }
  }
}
