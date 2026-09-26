# Admin dashboard metrics catalogue

Every number on an insurer-admin or superadmin dashboard comes from one function in
`backend/src/admin/metrics.ts`, which only runs `SELECT`s on the tables named below. Nothing is
estimated, sampled or hard-coded. If a signal is not stored, the dashboard says so (`notMeasured`)
instead of showing a number.

**Scope rule.** An INSURER_ADMIN always gets its token's tenant (a `tenantId` parameter is
rejected with 400). A SUPERADMIN gets the platform, or one tenant when it filters the audit log.

**Window.** Metrics marked *windowed* use `?days=` (1 to 365, default 30), counted back from the
request time. The others are current totals.

## Claims
| Metric | Definition | Source | Windowed |
|---|---|---|---|
| Lodged claims (`claims.total`) | Claims in any stage except `Draft` | `claims.stage`, `claims.tenant_id` | no |
| Open claims (`claims.open`) | Lodged claims not in `Paid`, `Withdrawn` or `Expired`. A rejected claim stays open in `Decision` because it can still be appealed. | `claims.stage` | no |
| Claims by stage | Count per lifecycle stage (zero-filled; `Draft` excluded) | `claims.stage` | no |

## Decisions and payouts
| Metric | Definition | Source | Windowed |
|---|---|---|---|
| Approved / rejected | Decisions recorded in the window, by outcome | `claim_decisions.outcome`, `decided_at` | yes |
| Approval rate | approved ÷ (approved + rejected) in the window; `null` when there were none | `claim_decisions` | yes |
| Median hours to decision | Median of (`decided_at` − `claims.created_at`) for decisions in the window whose claim has `created_at` | `claim_decisions` joined to `claims` | yes |
| Payouts, count and total | Simulated payouts initiated in the window; total in cents | `payouts.amount_cents`, `initiated_at` | yes |

## Advisory screening (Phase 4)
| Metric | Definition | Source | Windowed |
|---|---|---|---|
| Band mix | Lodged claims per band: `NORMAL`, `ELEVATED` (stored `UNUSUAL`), `HIGH` (stored `HIGH_ANOMALY`) | `screening_signals.interpretation` joined to `claims` | no |
| Unscreened | Lodged claims without a stored signal | `claims` minus `screening_signals` | no |
| By execution / model version (platform) | Signals per `execution` (`simulator` / `hardware`) and per `model_version` | `screening_signals` | no |

The band is advisory screening context. It never approves, rejects or moves a claim, and the UI
labels it as advisory.

## Decision integrity (Phase 5, ML-DSA-65)
| Metric | Definition | Source | Windowed |
|---|---|---|---|
| Signed / unsigned decisions | Decisions with / without `integrity_alg` recorded | `claim_decisions.integrity_alg` | no |
| By key id (platform) | Signed decisions per `integrity_key_id` (shows key rotation) | `claim_decisions.integrity_key_id` | no |
| Verifications by status | `/decision/verify` results in the window: `VALID`, `TAMPERED`, `UNSIGNED`, `UNKNOWN_KEY`, `UNAVAILABLE` | `audit_events` rows with action `decision.integrity_verified`, `details.status` | yes |

## Staff and accounts
| Metric | Definition | Source | Windowed |
|---|---|---|---|
| Staff by role, active / disabled (tenant) | Accounts whose `tenant_id` is the tenant | `users.role`, `users.status` | no |
| Users by role (platform) | All accounts per role | `users.role` | no |
| Per-tenant summary (platform) | Lodged and open claims, staff, active insurer admins, decisions and payouts in the window, per tenant | `tenants`, `claims`, `users`, `claim_decisions`, `payouts` | partly |
| Disabled accounts (platform) | Accounts with `status = 'disabled'` | `users.status` | no |

## Pending work
| Metric | Definition | Source | Windowed |
|---|---|---|---|
| Insurer applications (platform) | Applications with `status = 'pending'` | `insurer_applications` | no |
| Policy requests (tenant) | This insurer's link requests with `status = 'pending'` | `policy_link_requests` | no |

## Security (platform)
| Metric | Definition | Source | Windowed |
|---|---|---|---|
| Logins | `auth.login` events, success vs denied (bad credentials or disabled account) | `audit_events` | yes |
| Denials by action | Top 10 actions with `outcome = 'denied'` (e.g. `authz.role_denied`, `authz.claim_access_denied`) | `audit_events` | yes |
| Failures by action | Top 10 actions with `outcome = 'failure'` | `audit_events` | yes |
| Denials by actor tenant | Denied events grouped by `actor_tenant_id` (null = customers, platform or unauthenticated) | `audit_events` | yes |
| Recent denied events | The latest 20 denied events inside the window | `audit_events` | yes |

**Not measured** (reported in `notMeasured`, never shown as zero):
- Rejected bearer tokens. The Worker logs them to its console but does not write audit rows.
- Rate-limited requests (429s).

## Audit log views
| View | Scope | Source |
|---|---|---|
| Tenant audit (`/tenant/audit`) | Events by the tenant's own staff, plus events on the tenant's claims, decisions, payouts, evidence, policies, accounts and tenant record. Actors outside the tenant (customers, platform operators, other insurers' staff) appear by role only. | `audit_events` |
| Platform audit (`/admin/audit`) | Everything, optionally narrowed to one tenant's scope | `audit_events` |

Both views page newest-first (`limit` 1 to 100, `before` cursor) and filter by `outcome` and
action prefix. They never return the `details` column. Reading either log writes its own audit
row (`tenant.audit_viewed` / `admin.audit_viewed`).

Tests: `backend/test/adminMetrics.test.ts` asserts every metric above against a fixed fixture.
