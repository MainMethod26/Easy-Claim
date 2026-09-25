# EasyClaim Security Documentation

> **WARNING: AUTHENTICATION IS NOT IMPLEMENTED.**
> The API identifies callers via `X-Dev-Actor-Id` / `X-Dev-Actor-Role` headers, which are only honoured when `ALLOW_DEV_ACTOR_HEADERS=true` (set in `backend/.dev.vars`, local only). These headers are **trivially spoofable** and exist only so authorization logic (ownership, RBAC, state machine, audit) can be built and tested now. Real authentication is owned by the **backend team** — see [BACKEND_SECURITY_HANDOFF.md](BACKEND_SECURITY_HANDOFF.md) BACKEND-SEC-001. Without the flag, every `/api/v1/*` request returns `401` (fails closed).

## Current security posture (branch `cyber`)

| Area | Status | Where |
|---|---|---|
| Authentication | NOT IMPLEMENTED (dev stub only) | `backend/src/security/actor.ts` → `resolveActor` |
| Function-level authorization (RBAC) | IMPLEMENTED, TESTED/PASSED | `backend/src/security/rbac.ts`, `test/rbac.test.ts` |
| Object-level authorization (claims, policies) | IMPLEMENTED, TESTED/PASSED | `backend/src/security/claimAccess.ts`, `test/bola.test.ts` |
| Tenant/org scoping for insurer staff | NOT IMPLEMENTED | any ASSESSOR/MANAGER can read any claim |
| Property-level authorization (mass assignment) | IMPLEMENTED, TESTED/PASSED | `backend/src/security/validation.ts` (strict zod), `test/massAssignment.test.ts` |
| Claim state machine | IMPLEMENTED (customer transitions exposed; insurer transitions have no endpoints yet) | `backend/src/security/claimStateMachine.ts`, `test/stateMachine.test.ts`, `test/claimLifecycle.test.ts` |
| Audit trail (append-only) | IMPLEMENTED, TESTED/PASSED | `backend/src/security/audit.ts`, `migrations/0002_security.sql`, `test/audit.test.ts` |
| Rate limiting | IMPLEMENTED (approximate, per IP) | `wrangler.toml` `[[ratelimits]]`, `src/index.ts` |
| Security headers, CORS allowlist, body limit, generic errors | IMPLEMENTED, TESTED/PASSED | `src/index.ts`, `test/hardening.test.ts` |
| Queue message validation | IMPLEMENTED, TESTED/PASSED | `src/endpoints/ocr.ts`, `test/queue.test.ts` |
| Evidence upload / storage | NOT IMPLEMENTED | only a queue event is sent |
| OCR / AI | NOT IMPLEMENTED | `/ocr/process` is a stub |
| Decisions / payouts | NOT IMPLEMENTED | no endpoints |
| Dependency vulnerabilities | `npm audit`: 0 found | `backend/package-lock.json` |

Verification evidence: 85/85 tests pass across 9 files; a mutation check that disabled the ownership check made 5 BOLA tests fail; `npm run typecheck` passes.

## Running the security tests

```bash
cd backend
npm install
npm test          # vitest + @cloudflare/vitest-plugin (real workerd + D1, fully local)
npm run typecheck
npm audit
```

Tests apply `migrations/` and `seed_sa_data.sql` to an isolated D1 per test file; they do not need `wrangler dev` running.

## Document index

| Document | Purpose |
|---|---|
| [../BACKEND_INVENTORY.md](../BACKEND_INVENTORY.md) | Verified repository inventory and endpoint table |
| [../architecture/BACKEND_ARCHITECTURE.md](../architecture/BACKEND_ARCHITECTURE.md) | Runtime architecture, request pipeline, data model |
| [SECURITY_REQUIREMENTS.md](SECURITY_REQUIREMENTS.md) | OWASP API Top 10 2023 / ASVS / SSDF mapped to EasyClaim |
| [THREAT_MODEL.md](THREAT_MODEL.md) | Assets, actors, trust boundaries, threats |
| [RBAC_MATRIX.md](RBAC_MATRIX.md) | Role × action permissions and ownership rules |
| [API_SECURITY_MATRIX.md](API_SECURITY_MATRIX.md) | Per-endpoint auth, role, object checks, risks |
| [CLAIM_STATE_SECURITY.md](CLAIM_STATE_SECURITY.md) | Claim lifecycle and transition rules |
| [EVIDENCE_SECURITY.md](EVIDENCE_SECURITY.md) | Evidence upload requirements (not implemented) |
| [DECISION_SECURITY.md](DECISION_SECURITY.md) | Decision protection and decision record |
| [PAYOUT_SECURITY.md](PAYOUT_SECURITY.md) | Payout protections (not implemented) |
| [AUDIT_SECURITY.md](AUDIT_SECURITY.md) | Audit events vs app logs |
| [AI_SECURITY.md](AI_SECURITY.md) | OCR/AI trust boundaries |
| [SECURITY_TEST_PLAN.md](SECURITY_TEST_PLAN.md) | Every security test and its status |
| [ATTACK_SCENARIOS.md](ATTACK_SCENARIOS.md) | 12 attack scenarios with before/after results |
| [SECURITY_IMPLEMENTATION_PLAN.md](SECURITY_IMPLEMENTATION_PLAN.md) | P0 / P1 / P2 / Bonus roadmap |
| [SECURITY_CHECKLIST.md](SECURITY_CHECKLIST.md) | Pre-demo and pre-deploy checklist |
| [BACKEND_SECURITY_HANDOFF.md](BACKEND_SECURITY_HANDOFF.md) | Concrete requirements for the backend team |
