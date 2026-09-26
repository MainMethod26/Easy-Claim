# Architecture fitness review: admin and superadmin consoles

**Update 27 Sep 2026:** the superadmin was shrunk to a platform operator with no claim access, and insurer
onboarding (apply → approve) and policy linking (request → insurer approves) were added. See the section at
the end.

Scope: branch `feature/admin-console`, on top of `main` at `abd8701` (the integration merge with the five-role model).
Date: 26 Sep 2026. Question: were the admin and superadmin experiences added without creating a second
architecture inside EasyClaim?

## Verdict

**Yes, with the gaps listed at the end.** Every new screen and endpoint goes through the existing sign-in, actor,
role check, tenant boundary, audit trail, API client and app. The new code is a read-only metrics service, thin
handlers inside the existing admin routers, presentation widgets, and one console per role behind the one router.

## One system, one source of truth

| Concern | The single implementation | Evidence |
|---|---|---|
| Authentication | `POST /auth/login` → HS256 token → `requireActor` (issuer, audience, lifetime, role and tenant shape) | No new auth code. `roleMatrix.test.ts` shows 12 kinds of forged or malformed admin tokens getting 401 on the new routes. |
| Actor model | `Actor {id, role, tenantId}` from `security/actor.ts` | The metrics service never reads the request; handlers pass `actor.tenantId`. |
| Authorization | `requireRole('SUPERADMIN')` on `/admin/*` and `requireRole('INSURER_ADMIN')` on `/tenant/*`, the existing router guards | The new routes are added to the existing `superadmin` and `tenantAdmin` routers. No `adminRequireRole` or similar. |
| Tenant model | Tenant only from the token; `?tenantId` rejected on tenant routes | `ADM-02`: tenantId in the query gives 400. `ADM-12`: tenant B sees only its own numbers. |
| Claim lifecycle | `transitionClaim` / state machine, unchanged | The dashboards are read-only. Admin roles still get 403 on every claim POST. |
| Audit | `writeAuditEvent` into append-only `audit_events` | Audit views read the same table and record their own `*.audit_viewed` row. |
| Schema | Migrations `0001`–`0010`, unchanged | No new tables or columns. Every metric is a SELECT on existing tables (`METRICS.md`). |
| Validation | zod schemas in `security/validation.ts` | Three schemas appended there (`metricsQuerySchema`, `tenantAuditQuerySchema`, `platformAuditQuerySchema`). |
| API client | `ApiClient.shared` with the `Session` token | New calls are methods on the existing `SuperadminRepository` and `TenantAdminRepository`. |
| Flutter app | One `main.dart` → `AuthScreen` → `homeFor` → role console | `main_admin.dart` is now a four-line alias that starts the same `EasyClaimApp`. |
| Theme | `EcTheme` (tokens + `ThemeExtension` status colours) in `main.dart` | Both inline `ThemeData` definitions are gone. Customer screens keep a white page (screenshot 10). |

## Checks

| Check | Result |
|---|---|
| Forged ADMIN/SUPERADMIN tokens | 401 for wrong key, `alg: none`, HS512, expired, over the 8 h cap, wrong issuer or audience, SUPERADMIN with a tenant, INSURER_ADMIN without one, missing `exp` (`roleMatrix.test.ts`) |
| Cross-tenant access | 404 for another tenant's claim for ASSESSOR, MANAGER and INSURER_ADMIN. Tenant audit shows outside actors by role only (`ADM-20`). |
| Superadmin acting as an insurer | 403 on verify, request-info, decide, pay, start claim and `/risk-signals` |
| Frontend role manipulation | The router is UX only. `X-Role` / `X-Tenant-Id` headers are ignored (403), and the backend re-checks every call. |
| Dev-auth leakage | The magic-word `/profile/login` is gone (401 or 404). Demo accounts exist only in local seeds. |
| Sensitive fields | Dashboard responses never contain bank names, last-4 digits, destination hashes, passwords or audit `details`. Tenant views never contain customer ids (`ADM-13`). |
| Fabricated metrics | None. Each KPI has a definition and SQL source in `METRICS.md`. Unmeasured signals are named in `notMeasured`, never shown as 0. |
| Thin endpoints and DTOs | Handlers are 1–10 lines. `metrics.ts` returns typed DTOs; Flutter mirrors them in `data/models/admin_models.dart`. |
| Contract | Every mounted admin/tenant route and every repository call is in `docs/API_CONTRACT.md` with the same method (`api_contract_test.dart`). |
| Legacy code | Nothing deleted. See the list below. |

## Verification run (26 Sep 2026)

| Suite | Result |
|---|---|
| Backend `tsc --noEmit` | clean |
| Backend vitest | 23 files, 437 tests passed (83 new: `adminMetrics` 13, `roleMatrix` 70) |
| `npm audit --omit=dev` | 0 vulnerabilities |
| Flutter `analyze` | no issues |
| Flutter `test` | 76 passed (22 new: design system 9, consoles 11, contract 2; routing tests updated) |
| Live run | Worker on 127.0.0.1:8791 with the local demo seed; web build on 127.0.0.1:5180; each role signed in through the real UI. Screenshots in `screenshots/`. |

The live run also drove a real claim from customer submission through assessor verify, screen and review to
manager approve and simulated payout. Its ML-DSA-65 signature verified VALID. Attacks during the run were all
refused: an assessor deciding got 403, a Sanlam assessor reading a Discovery claim got 404, a wrong password got
401, an unsigned SUPERADMIN token got 401, and an assessor opening `/admin` got 403. Each refusal appears in the
security centre.

## Bugs found and fixed during the review

- **Selectable ID text swallowed row taps.** Clicking a claim's ID did not open the claim. `EcIdText` is now plain
  text with a tooltip, and a widget test covers the tap.
- **Misleading "admin(s)" label.** The Insurers screen counted every staff account but labelled them "admin(s)".
  The label now says "staff".
- **Reassuring chip on a zero count.** The integrity KPI "Tampered on verify" showed a green "Verified" chip at zero.
  It now shows "None".

## Legacy code left in place (unreferenced by routing, not deleted)

- `screens/admin/insurer_dashboard_screen.dart`: only its `stageColor` helper is still imported, by the next item.
- `screens/superadmin/superadmin_shell.dart`, `superadmin_dashboard_screen.dart` (`/admin/stats`) and
  `superadmin_claims_screen.dart`: replaced by `SuperadminConsole`. `widget_test.dart` still imports the dashboard screen.
- `GET /admin/stats` and `GET /tenant/stats`: still used by `InsurerTeamScreen` and the tests. They overlap with
  the new overviews.

Removing these is a follow-up once the team agrees; it changes no behaviour.

## Known gaps (not built here)

See `ROLE_MATRIX.md` → "Not built yet":
- no backend step-up or recorded reason on account status changes;
- no insurer suspension or role change endpoints;
- disabled accounts keep their token until it expires;
- SUPERADMIN evidence download: closed on 27 Sep (see the update below);
- rejected tokens and 429s are not audited.

## Update 27 Sep 2026: platform operator, onboarding, policy linking

| Change | How it stays in one system | Evidence |
|---|---|---|
| SUPERADMIN has no claim access | One change in `loadAuthorizedClaim`, which guards every per-claim route, plus the `GET /claims` branch removed | `roleMatrix.test.ts`: 404 on claim, evidence and verify; 403 on `/claims`. `tenant`, `rbac`, `attackSuite` and `endToEnd` updated. |
| SUPERADMIN manages only insurer admins | `/admin/users` lists INSURER_ADMIN (and superadmins); PATCH on anyone else → 404 | `accounts.test.ts`, `roleMatrix.test.ts` |
| Insurer onboarding | Public route on the existing `authPublic` router; review routes on the existing `superadmin` router; `hashPassword` reused; approval is one D1 batch creating tenant + user; each audit row gated on its write | `onboarding.test.ts` ONB-01..06 |
| Policy linking | Customer routes on the existing covers router (`requireRole('CUSTOMER')`, user from the token); decisions on the existing `tenantAdmin` router (tenant from the token; another tenant's request → 404); approval creates the policy in one batch | `onboarding.test.ts` LINK-01..06 (including a claim started on the linked policy) |
| Schema | One additive migration, `0011_onboarding_policy_links.sql`: partial unique indexes enforce one pending application per username / FSP number and one pending request per policy number | tests above |
| Gap closed | "SUPERADMIN can download evidence bytes" is gone with the claim access | ATTACK-21 |

**Verification.** Backend: 453 tests, typecheck clean, 0 vulnerabilities. Flutter: 76 tests, analysis clean.
The live run on 27 Sep went through the real UI:
1. Hollard applied through the public form.
2. The superadmin approved the application.
3. `admin_hollard` signed in and added an assessor and a manager.
4. The new customer `thandi` asked to link policy HOL-2026-0042.
5. The Hollard admin approved it in the dialog.
6. Thandi's claim went verify → screen → review. The assessor was refused when trying to decide (403).
7. The manager approved and paid R 18 500.00, and the signature verified as VALID ML-DSA-65.
8. The superadmin got 404 and 403 on claims.

Screenshots 11–19 are in `screenshots/`. Two steps were driven through the API instead of clicks: the customer's
insurer dropdown (headless automation could not open the menu) and the approval call (the same one the
Approve button makes). Both screens were checked by screenshot.
