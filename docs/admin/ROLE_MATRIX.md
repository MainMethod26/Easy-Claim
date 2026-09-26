# Role / permission / tenant matrix

Status: matches `main` at `abd8701` plus the admin-console branch (updated 27 Sep 2026: superadmin shrunk to a platform operator; insurer onboarding and policy linking added). Every row is enforced on the server;
a hidden button is never the control. `backend/test/roleMatrix.test.ts` checks each row against the real
routes, and `backend/test/adminMetrics.test.ts` checks the dashboard rows.

**Roles** (decided 26 Sep 2026): CUSTOMER, ASSESSOR, MANAGER, INSURER_ADMIN, SUPERADMIN.

**Tenant scope.** The tenant always comes from the verified token (`tenant_id`), never from a request.
- CUSTOMER has no tenant. It owns records by `user_id`.
- ASSESSOR, MANAGER and INSURER_ADMIN belong to exactly one tenant.
- SUPERADMIN has no tenant. A SUPERADMIN token that carries a tenant is rejected with 401.

**One system.** There is one sign-in (`POST /auth/login`) and one token type (HS256, issuer, audience and
lifetime checked). There is one actor model (`requireActor`), one role check (`requireRole`), one claim state
machine (`transitionClaim`), one audit trail (`audit_events`) and one Flutter app, whose role router is
`homeFor` in `frontend/lib/screens/auth_screen.dart`.

## Capabilities

| Capability | CUSTOMER | ASSESSOR | MANAGER | INSURER_ADMIN | SUPERADMIN | Audit event |
|---|:-:|:-:|:-:|:-:|:-:|---|
| Sign in | ✓ | ✓ | ✓ | ✓ | ✓ | `auth.login` (success / denied) |
| Self-register | ✓ (always CUSTOMER) | | | | | `auth.register` |
| Apply as an insurer (public form, no account yet) | anyone | | | | | `onboarding.application_submitted` |
| Review insurer applications: approve (creates tenant + first INSURER_ADMIN) or reject with reason | | | | | ✓ | `onboarding.application_approved` / `_rejected` |
| Request to link an existing policy (insurer + policy number) | ✓ | | | | | `cover.link_requested` |
| Approve (creates the policy) or reject a policy link request | | | | ✓ own tenant | | `policy.link_approved` / `policy.link_rejected` |
| Own claims: start, describe, payout details, evidence, submit, withdraw, appeal | ✓ | | | | | `claim.*`, `evidence.uploaded` |
| Read a claim, its timeline, decision, payout and evidence | own | own tenant | own tenant | own tenant, read-only | ✗ (404; `/claims` 403) | denials: `authz.claim_access_denied` |
| Advisory risk signals (`/risk-signals`) | 403 | ✓ | ✓ | 403 | 403 | `screening.signal_read` |
| Verify, screen, review, request info | | ✓ | ✓ | | | `claim.stage_changed` |
| Decide, signed with ML-DSA-65 | | | ✓ | | | `claim.decision_recorded` |
| Pay (simulated), re-open an appeal | | | ✓ | | | `payout.completed_simulated` |
| Verify a decision signature | owner | own tenant | own tenant | own tenant | ✗ (aggregate counts only) | `decision.integrity_verified` |
| Tenant dashboard (`/tenant/overview`) | | | | ✓ | | – |
| Tenant audit log (`/tenant/audit`) | | | | ✓ | | `tenant.audit_viewed` |
| Tenant staff: create ASSESSOR, MANAGER or INSURER_ADMIN; enable or disable | | | | ✓ own tenant | | `tenant.user_created`, `tenant.user_status_changed` |
| Create insurers (tenants) | | | | | ✓ | `admin.tenant_created` |
| Create, list, enable or disable INSURER_ADMIN accounts (not assessors or managers) | | | | | ✓ | `admin.user_created`, `admin.user_status_changed` |
| Platform overview, security centre, integrity, global audit | | | | | ✓ | `admin.audit_viewed` (audit view only) |
| Create a SUPERADMIN, or change another one | | | | | ✗ (no API; operator-managed) | – |
| Any claim transition | per state machine | per state machine | per state machine | ✗ | ✗ | `claim.transition_rejected` |

## Expected responses (asserted by the tests)

| Request | Actor | Expected |
|---|---|---|
| Any claim POST (verify, screen, review, request-info, decide, pay, appeal) | INSURER_ADMIN, SUPERADMIN, CUSTOMER | 403 |
| Decide or pay | ASSESSOR | 403 |
| `GET /claims/:id/risk-signals` | CUSTOMER, INSURER_ADMIN, SUPERADMIN | 403 |
| Another tenant's claim or draft | ASSESSOR, MANAGER, INSURER_ADMIN | 404, never 403, so a claim's existence is not leaked |
| `POST /admin/users` with role INSURER_ADMIN | SUPERADMIN | 201 |
| `POST /admin/users` with role SUPERADMIN or ASSESSOR | SUPERADMIN | 400 |
| `PATCH /admin/users/:id` on another superadmin | SUPERADMIN | 409 `superadmin_managed_offline` |
| `POST /tenant/users` with role SUPERADMIN, or naming a `tenantId` | INSURER_ADMIN | 400 |
| `PATCH /tenant/users/:id` on another tenant's user or on a superadmin | INSURER_ADMIN | 404 |
| `/tenant/*` | ASSESSOR, MANAGER, SUPERADMIN | 403 |
| `/admin/*` | everyone but SUPERADMIN | 403 |
| `?tenantId=` on `/tenant/overview` or `/tenant/audit` | INSURER_ADMIN | 400 |
| Token that is unsigned (`alg: none`), signed with the wrong key or algorithm, expired, over the 8-hour staff lifetime, from the wrong issuer or audience, SUPERADMIN with a tenant, or INSURER_ADMIN without one | anyone | 401 |
| Any claim read (`/claims/:id`, timeline, evidence, `/decision/verify`) | SUPERADMIN | 404; `GET /claims` 403 |
| `PATCH /admin/users/:id` on an assessor, manager or customer | SUPERADMIN | 404 |
| Approve or reject an insurer application | anyone but SUPERADMIN | 403; deciding twice 409 |
| Approve or reject another insurer's policy request | INSURER_ADMIN of another tenant | 404 |
| Policy request decisions | ASSESSOR, MANAGER, SUPERADMIN | 403 |
| `X-Role` / `X-Tenant-Id` headers | anyone | ignored |
| Retired magic-word login `POST /profile/login` | anyone | 401 without a token, 404 with one |

## Not built yet (known gaps, not silently assumed)

- **Step-up authentication** before sensitive admin actions. The app has a confirm-with-reason dialog
  (`showEcConfirmWithReason`), but the backend status-change routes do not take a reason yet, so none is recorded.
- **Suspending an insurer** and **changing a user's role**. There are no endpoints; accounts can only be enabled or disabled.
- **Session revocation.** A disabled account keeps a valid token until it expires (at most 8 hours for staff).
- **Rejected tokens and 429s** are logged to the Worker console, not to `audit_events`, so the security centre
  lists them under "Not measured".

Local demo accounts (seeded locally only, password `1234567`, never deployed): `superadmin`, `admin_discovery`,
`admin_sanlam`, `assessor_discovery`, `manager_discovery`, `assessor_sanlam`, `manager_sanlam`, `mike`, `lerato`, `sipho`.
