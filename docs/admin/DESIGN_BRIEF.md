# Admin console design brief (research 26 Sep 2026; implemented on the admin-console branch)

Principle: professional = restraint. One accent, neutral greys doing most of the work, a small token set, real data density.
References: Stripe Dashboard (one headline chart per page, restrained colour, monospace copyable IDs), Linear (density,
alignment, few theme inputs), Clerk/WorkOS (org switcher, invitations, roles, audit portal), Guidewire ClaimCenter/Jutro
(work queues), Material 3 layout guidance. Sources: linear.app/now/how-we-redesigned-the-linear-ui; shadcn.io/design/stripe;
m3.material.io/foundations/layout; nngroup.com (chart choice, preattentive attributes); cheatsheetseries.owasp.org
Multi-Tenant; engineering.pigment.com safe impersonation; docs.github.com sudo mode; carbondesignsystem.com loading.

## Tokens (extend the existing theme; no second design system)
- Colour: existing EasyClaim orange `#FF5500` as the single accent; slate neutrals already used (`0F172A`, `64748B`,
  `E2E8F0`, `F1F5F9`, `F8FAFC`); semantic colours via `ThemeExtension` (success `16A34A`, warning `F59E0B`, danger
  `EF4444`, info `0055FF`) in light and dark.
- Type: Plus Jakarta Sans (already the app font); tabular figures for numbers; 12/14/16/20/28 scale.
- Space 4/8/12/16/24/32; radius 8; `VisualDensity.compact` on desktop; 1px borders, minimal shadow.

## Shell (one app, role-routed)
- M3 breakpoints: <600 modal drawer · 600–1199 NavigationRail · ≥1200 extended sidebar (256 px).
- Top bar: tenant name badge (INSURER_ADMIN) or "Platform" badge (SUPERADMIN); user menu with role, tenant, token
  expiry, sign out; light/dark toggle.

## Components
KPI card (label, value, delta, optional sparkline) · status chip = icon + label (never colour alone, WCAG 1.4.1):
claim stage (neutral), band NORMAL/ELEVATED/HIGH, integrity Verified/Tampered/Unsigned · data table (sticky header,
pagination, quick filters, skeleton first load, empty state with next action) · detail side drawer · confirm dialog with
required reason for sensitive actions · charts: bars for categories (claims by stage), line for time series, no donut
beyond 4 slices, no truncated axes.

## Pages
INSURER_ADMIN: Overview · Claims (read-only, masked) · Team (accounts, invite, roles) · Integrity & screening · Audit log.
SUPERADMIN: Platform overview · Insurers (tenants) · Insurer admins · Security centre · Integrity & crypto · Global audit.

## Security UX
Mask PII by default (bank `•••• 1234`, no ID numbers); denied audit rows visually distinct; "advisory" label on every
screening number; ML-DSA key id and signature status shown with a shield icon; no impersonation in this version.

## What was built, and what was deferred

Built as the brief describes: the tokens, the semantic status colours (light and dark, AA contrast tested), the
responsive shell at the M3 breakpoints, the scope badge and user menu, KPI cards with a definition caption, status
chips with icon and label, dense tables with loading, empty and error states, bar charts and proportion bars
(no donuts), the advisory label on screening data, and the confirm-with-reason dialog.

Deliberately deferred, so the first version stays small and honest:
- **KPI deltas and sparklines.** They need a time series the backend does not return yet.
- **Line charts, and a detail side drawer.** Claims open in the existing claim file screen instead.
- **A light/dark toggle in the UI.** Dark tokens exist and are tested, but customer screens are light-only.
- **`data_table_2`.** Flutter's own `DataTable` in a horizontal scroll view is enough at this data size and adds no dependency.
- **`fl_chart`.** `main` removed it, so the bar chart is plain widgets.
- **INSURER_ADMIN "Integrity & screening" page.** It is folded into the Overview as two cards.
- **PII masking beyond what the API already does.** Admin DTOs carry no names, ID numbers or bank fields at all.

## Implementation map
| Brief item | File |
|---|---|
| Tokens (colour, spacing, radius, breakpoints, tabular figures) | `frontend/lib/core/theme/ec_tokens.dart` |
| Semantic status colours, light + dark | `frontend/lib/core/theme/ec_status_colors.dart` (`ThemeExtension`) |
| One theme for every role | `frontend/lib/core/theme/ec_theme.dart`, applied in `main.dart` |
| Responsive shell, scope badge, user menu | `frontend/lib/core/widgets/admin/ec_admin_shell.dart` |
| KPI card and grid; status chip; table and ID text; section and page frame; charts; reason dialog | `frontend/lib/core/widgets/admin/*` |
| Role router (one sign-in, one app) | `homeFor` in `frontend/lib/screens/auth_screen.dart` |
| Consoles: ClaimStaff (assessor, manager), InsurerAdmin, Superadmin | `frontend/lib/screens/console/role_consoles.dart` |
| Pages: overviews, security, integrity, audit log, claims worklist | `frontend/lib/screens/console/*` |
| Dashboard data (read-only SQL, DTOs) | `backend/src/admin/metrics.ts`, metric definitions in `METRICS.md` |

The widgets hold no auth, role or API logic. Consoles get their data through the existing `ApiClient` and
repositories (`SuperadminRepository`, `TenantAdminRepository`, `InsurerRepository`).
Tests: `frontend/test/admin_design_system_test.dart`, `console_test.dart`, `api_contract_test.dart`, `widget_test.dart`.
Screenshots of the live run: `docs/admin/screenshots/`.
