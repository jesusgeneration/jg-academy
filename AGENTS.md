# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this is

**Juleica Tracker** — a Rails portal for cooperating churches that offer
one-off training events. It records course attendance and derives each
person's progress toward Juleica requirements.

Read before making architectural decisions:

- `docs/PRODUCT_REQUIREMENTS (1).md` — the product specification
- `docs/AI_AGENT_GUIDE.md` — domain rules and implementation guardrails

## Commands

```bash
bin/rails db:test:prepare   # sync test database with schema
bundle exec rspec           # run test suite (must pass before finishing work)
bundle exec rubocop         # Rails Omakase style (must pass)
bin/rails db:seed           # demo dataset incl. login accounts
bin/dev                     # run app locally (Rails + Tailwind watcher)
```

Stack: Ruby 4.0 / Rails 8.1 / PostgreSQL / Propshaft + importmap /
Tailwind CSS v4 + DaisyUI 5 (`tailwindcss-rails`) / Devise / Pundit /
RSpec + FactoryBot. No Node build step.

## Architecture Map

| Path | Purpose |
| --- | --- |
| `app/models/` | Domain models (see diagram below) |
| `app/services/juleica_progress_calculator.rb` | All progress logic |
| `app/policies/` | Pundit authorization per resource |
| `app/controllers/dashboards_controller.rb` | Staff dashboard; redirects participants to their progress page |
| `app/views/layouts/application.html.erb` | Portal shell (drawer sidebar + navbar) |
| `app/views/layouts/devise.html.erb` | Centered card layout for sign-in/up pages |
| `db/migrate/`, `db/schema.rb` | Schema with FKs, composite unique indexes, check constraints |
| `spec/` | `models/`, `services/`, `policies/`, `requests/`, `factories.rb` |

Domain relationships:

```text
User --OrganizationMembership--> Organization <--organization_id-- Course
User --CourseAttendance--> Course --CourseRequirement--> JuleicaRequirement
```

## Non-Negotiable Domain Rules

1. **A Course is a one-off real-world event.** Never introduce
   `CourseOccurrence`, course templates, or recurring instances.
2. **Progress is derived, never stored.** Do not add cached
   `earned_hours`/`completed` columns or callbacks that write them. Everything
   flows through `JuleicaProgressCalculator` (`User#juleica_progress`).
3. **Only `attended` attendance earns credit.** Registered/cancelled/no_show
   never count.
4. **Requirements are data, not code.** Never hard-code requirement names,
   hour thresholds, or module lists.
5. **Database integrity mirrors validations:** unique indexes on
   `[user_id, course_id]`, `[course_id, juleica_requirement_id]`,
   `[user_id, organization_id]`; check constraints enforce positive hours;
   use foreign keys. Add both validation *and* constraint for new invariants.
6. Hours are `decimal(6,2)` — half-hours are valid, negative/zero are not.
7. Future concepts (`QualificationEvidence`, `RequirementSet`, certificates…)
   stay unimplemented until a requirement explicitly asks.

## Authorization

Two system roles on `User.role`: `user` (default) and `admin`. Organizing
authority is per-organization via `OrganizationMembership.role`
(`member` < `organiser`). Participation in courses is represented only by
`CourseAttendance` — any user can attend, including organisers.

- Every portal controller inherits `BaseController` (enforces sign-in).
- Every action calls `authorize`; collections call `policy_scope`.
- Matrix: plain users browse courses + own progress; organisers manage
  courses, attendance and rosters **of their own organizations only**
  (`user.organises?(organization)`); admins manage organizations, juleica
  requirements, users and deletions. The staff dashboard is visible to
  admins and organisers; everyone else lands on their progress page.
- Course forms must limit organization options to permitted ones; the
  controller clamps `organization_id` server-side for non-admins (see
  `CoursesController#ensure_permitted_organization`). Keep that clamp when
  refactoring course create/update.
- Unauthorized access redirects with a flash alert (see
  `ApplicationController#user_not_authorized`).

## Testing Conventions

- FactoryBot syntax methods are globally included (`create`, `build`);
  factories live in `spec/factories.rb`. Users are confirmed by default
  (Devise confirmable); use `:unconfirmed` trait when needed.
- Request specs use `sign_in user` from `Devise::Test::IntegrationHelpers`
  (already configured for `type: :request`). They render views, so they catch
  template errors — prefer them over controller specs.
- Policy specs must use Pundit ≥ 2.5 style:
  `permissions :show? do ... expect(policy_class).to permit(user, record)` —
  the legacy `permit_action(s)` matchers no longer exist.
- The central domain scenario (guide §13: two courses × 4h → 4/8 → attended →
  8/8) has specs in `spec/services/juleica_progress_calculator_spec.rb` and an
  end-to-end version in `spec/requests/user_progress_spec.rb`. Keep them
  passing through any refactor.
- Calculator results memoize per instance; always instantiate a fresh
  `JuleicaProgressCalculator` per calculation in specs.

## UI Conventions

- DaisyUI components only when a suitable component exists (navbar, drawer,
  menu, table, badge, stat, progress, alert, modal, fieldset…). Tailwind
  utilities for layout/spacing. No second design system, no custom lookalikes.
- Classic admin-portal layout: persistent drawer sidebar on desktop,
  collapsible on mobile; active nav item gets `menu-active`.
- Sidebar entries are role-filtered via policies (see
  `ApplicationHelper#portal_nav_items`).
- Flash messages render through `shared/_flash` as DaisyUI alerts.
- Status colors: attendance badges via
  `attendance_status_badge_class`, progress via success (complete) /
  primary (partial) bars.

## Gotchas

- **Routes:** Devise is mounted at `/auth` (`devise_for :users, path: "auth"`).
  This frees `/users/*` for the admin `UsersController` — mounting Devise back
  on default paths makes `POST /users` hit registrations instead of
  `UsersController#create`.
- **Nested attributes:** `course_requirements_attributes` requires
  `params.require(:course).permit(...)`; `params.expect` silently drops the
  dynamic `"0"` wrapper keys. Use require+permit for nested forms.
- Array params need array permits: `organization_ids: []`, not
  `:organization_ids`.
- Use `:unprocessable_content` (not the deprecated `:unprocessable_entity`).
- After schema changes run `bin/rails db:migrate && bin/rails db:test:prepare`
  so request specs don't fail on stale test schema.

## Definition of Done

1. `bundle exec rspec` — all green
2. `bundle exec rubocop` — no offenses
3. New behavior covered by specs (model/service/policy/request as fitting)
4. Every controller action has at least one spec asserting its response
   status (render or redirect) — including GET pages that only render forms
5. Migrations reversible; schema.rb committed alongside
