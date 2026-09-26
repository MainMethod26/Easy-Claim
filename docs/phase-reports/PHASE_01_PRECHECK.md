# Phase 1 Precheck: does the repository match the Phase 0 report?

Date: 2026-09-26
Branch: `cyber`
HEAD at precheck: `1468897` (Phase 0 implementation commit: `c73f3e1`; base `main`: `efb6cc3`)
Working tree: clean
PR: https://github.com/MainMethod26/Easy-Claim/pull/1

Method: five independent read-only verifiers each checked a group of Phase 0 claims against the
actual code, migrations, tests and docs. One verifier re-ran the tool chain. Nothing was modified.
The repository is the source of truth; where it disagrees with the report, the repository wins.

## 1. Tool chain re-run (backend/, HEAD 1468897)

| Command | Result |
|---|---|
| `npm test` | Test Files 9 passed (9), Tests 85 passed (85) (vitest 4.1.11) |
| `npm run typecheck` | `tsc --noEmit` exit 0 |
| `npm audit` | found 0 vulnerabilities (first attempt hit a network `socket hang up`; retry succeeded) |

Versions: node v24.19.0, hono 4.13.9, typescript 7.0.2, wrangler 4.141.0, zod 4.6.5,
@hono/zod-validator 0.9.1, vitest 4.1.11, @cloudflare/vitest-plugin 1.2.8.

## 2. Phase 0 claims: verdicts

171 individual checks were made. 165 MATCHED, 3 were DISCREPANCIES (all documentation wording),
3 COULD NOT BE VERIFIED statically (runtime observations). No code claim was wrong.

| Phase 0 claim | Verdict | Evidence |
|---|---|---|
| Cloudflare Worker + Hono + TypeScript + D1 + Queue | MATCHES | `backend/wrangler.toml`, `backend/package.json`, `backend/src/index.ts` |
| 24 backend endpoints | MATCHES | 14 GET, 8 POST, 2 PATCH across 6 routers; `index.ts` defines no leaf routes |
| 85 tests, 9 files, 85/85 pass | MATCHES | re-run above |
| typecheck passes | MATCHES | re-run above |
| npm audit checked | MATCHES | 0 vulnerabilities |
| Authentication is NOT real; `resolveActor()` is a local-only dev header mechanism | MATCHES | `backend/src/security/actor.ts` L18-21: `X-Dev-Actor-Id` / `X-Dev-Actor-Role` honoured only when `ALLOW_DEV_ACTOR_HEADERS === 'true'`; not set in `wrangler.toml`; set in `.dev.vars` and `vitest.config.mts` |
| Insurer roles lack tenant scoping | MATCHES | grep for tenant/org/organisation in `backend/src` and `backend/migrations`: zero hits except the ignored `:tenantId` path param on the identity stub (`identity.ts` L11) |
| verify / screen / decide / pay not implemented as endpoints | MATCHES | state machine permits the transitions, but no HTTP route exercises them; covered only by `test/stateMachine.test.ts` |
| Claim state transitions centralized | MATCHES | `claimStateMachine.ts` (18 legal edges) + `claimAccess.ts` `transitionClaim()` with conditional `UPDATE ... WHERE stage = ?` |
| `audit_events` exists, append-only | MATCHES | `migrations/0002_security.sql`; UPDATE/DELETE triggers |
| Object-level authorization exists | MATCHES | `loadAuthorizedClaim()` modes `read` / `owner-write`; deny and missing both → 404 |
| Strict validation exists | MATCHES | `.strict()` zod schemas on every data-bearing route; stubs `PATCH /profile` and `GET /profile/mandates/:tenantId/check` have none (already flagged in Phase 0 docs) |
| Security headers / CORS / body limit / rate limit | MATCHES | `index.ts`: `secureHeaders`, CORS origin allowlist with `allowHeaders = ['Content-Type','Authorization','X-Dev-Actor-Id','X-Dev-Actor-Role']`, body limit 65 536 bytes, `RATE_LIMITER` 100 req / 60 s keyed on `cf-connecting-ip` (optional binding) |
| Queue validation exists | MATCHES | `ocr.ts` zod schema on message body |
| Claim IDs are UUIDs | MATCHES (nuance) | `claim_` + `crypto.randomUUID()` — prefixed UUID, not a bare UUID |
| README replaced; security docs and handoff exist | MATCHES | 18 docs present |

## 3. Discrepancies (documentation only)

| # | Location | Problem | Action in Phase 1 |
|---|---|---|---|
| D1 | `docs/security/README.md:22` | "Decisions / payouts — NOT IMPLEMENTED — no endpoints" but a read-only `GET /claims/:claimId/decision` exists (`claims.ts` L190-196). Other docs already say PARTIAL. | Reword to "no decision-making or payout endpoints; `GET /decision` is read-only" |
| D2 | `docs/security/ATTACK_SCENARIOS.md:56` | Evidence tampering cross-references BACKEND-SEC-008 (OCR/AI); evidence upload is BACKEND-SEC-007 | Fix cross-reference |
| D3 | `docs/security/SECURITY_IMPLEMENTATION_PLAN.md:15` | Row label "Secure claim state transitions" uses the banned word as a control name | Rename to "Claim state transition enforcement" |

## 4. Could not be verified statically (runtime observations from Phase 0)

| Claim | Status | Note |
|---|---|---|
| Queue consumer does not fire under `wrangler dev` | NOT RE-VERIFIED | needs a live session; will be re-observed during Phase 1 live checks |
| Mutation check made "5 tests in bola.test.ts fail" | PLAUSIBLE, count nuance | static reading agrees for `bola.test.ts`; `rbac.test.ts:15` ("admin has no claim-reading powers") would also fail, so a whole-suite count would be **6**, not 5 |
| Live rate-limit burst: 113×200, 7×429 | NOT RE-VERIFIED | code path exists (`index.ts` L40-47); numbers are approximate by design |

Also noted: `SECURITY_TEST_PLAN.md:64` says "12 legal transitions allowed" — that is the number of rows in the unit test, not the 18 legal edges in `TRANSITIONS`.

## 5. Facts established for the Phase 1 design

### Data model
- `policies(id, user_id, plan_name, status)`; `claims(id, user_id, policy_id, stage, status, category, cause_of_loss, incident_date, created_at, updated_at)`; `audit_events`; `evidence` (unused).
- No tenant / organisation / insurer identifier exists on any table, on `Actor`, or in any token.
- Seed policies: `user123` holds Discovery, Sanlam and Old Mutual policies; `user456` OUTsurance; `user789` Momentum. Seed claims: `claim_disc_101` (user123, Review/Processing), `claim_sanlam_102` (user123, Decision/Approved), `claim_mom_103` (user789, Submitted/Pending).
- Consequence: a customer's policies span several insurers, so customers are **platform-level actors**, not members of one insurer tenant. Tenant membership applies to insurer staff.
- `status` values in use: Pending, Processing, Approved, Rejected. No endpoint sets Rejected, so `POST /appeal` is unreachable via the API today without a direct DB edit.

### `hono/jwt` (installed 4.13.9), verified by reading `dist/utils/jwt/jwt.js` and by a throwaway Node probe
- `verify(token, key, { alg, iss, aud, nbf=true, exp=true, iat=true })`. Header `alg` must equal the pinned `alg` or `JwtAlgorithmMismatch` is thrown; `alg: none` → `JwtHeaderInvalid`; HS512 token against pinned HS256 → `JwtAlgorithmMismatch`.
- `exp`, `nbf`, `iat` are validated **only if present**. `sub` is not required. **Phase 1 must require `exp` and `sub` explicitly.**
- `iss` exact string match; `aud` matches any element of the token's `aud` array. Use strings, not RegExp (unanchored regex over-matches).
- `typ` header is enforced only if present (must equal `JWT`).
- Error messages of the `Jwt*` classes embed the raw token / payload; a crafted null payload throws a bare `TypeError`. **Catch everything, log only `err.name`, never return the message.**
- `sign(payload, key, alg='HS256')` adds no claims; it can sign HS512 (useful for negative tests).
- Secret as a plain string: hono sniffs for the substrings `PRIVATE`/`PUBLIC` to detect PEM keys, so use a hex-encoded random secret.
- `verifyWithJwks()` exists for a future identity provider (refuses symmetric algorithms) — the migration path to an external IdP.
- Import path: `import { sign, verify } from 'hono/jwt'`.

### Test infrastructure
- Tests inject actors via `test/helpers.ts` `call({ as })`, which sets the dev headers; `vitest.config.mts` sets `ALLOW_DEV_ACTOR_HEADERS` and `ALLOWED_ORIGINS` as miniflare bindings. The plugin also loads the untracked `backend/.dev.vars` if present.
- Test actors: `customerA=user123`, `customerB=user456`, `assessor=assessor1`, `manager=manager1`, `admin=admin1`.
- The rate-limit middleware passes silently when the `RATE_LIMITER` binding is absent; tests inject a denying stub to test 429.

### Everything that mentions the dev actor stub (must change in Phase 1)
`README.md` (lines 12, 40, 57, 113-126), `docs/BACKEND_INVENTORY.md` (29, 58, 64, 117),
`docs/security/README.md` (4, 10), `BACKEND_SECURITY_HANDOFF.md` (10, 22-25), `SECURITY_IMPLEMENTATION_PLAN.md` (9-10),
`SECURITY_TEST_PLAN.md` (11, 13, auth section), `ATTACK_SCENARIOS.md` (curl examples), `SECURITY_CHECKLIST.md`,
`API_SECURITY_MATRIX.md`, `RBAC_MATRIX.md`, `THREAT_MODEL.md`, `docs/architecture/BACKEND_ARCHITECTURE.md`,
`backend/src/security/actor.ts`, `backend/src/types.ts`, `backend/src/index.ts` (CORS allow-headers),
`backend/.dev.vars.example`, `backend/vitest.config.mts`, `backend/test/helpers.ts`, `backend/test/actor.test.ts`,
`backend/EasyClaim.postman_collection.json`.

## 6. Conclusion

The repository matches the Phase 0 report. Phase 1 can proceed on the stated starting state. The three
documentation discrepancies will be corrected as part of the Phase 1 documentation update; no history is rewritten.
