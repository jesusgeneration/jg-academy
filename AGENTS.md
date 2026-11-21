# AGENTS.md

Guidance for AI coding agents working in this repository.

## What this is

**Juleica Tracker** — a Rails portal for cooperating churches that offer
training programs (schoolings, freizeiten) made of one-off units. It records
unit attendance and derives each person's progress toward Juleica requirements.

Read before making architectural decisions:

- `docs/PRODUCT_REQUIREMENTS (1).md` — the product specification
- `docs/AI_AGENT_GUIDE.md` — domain rules and implementation guardrails

## Commands

```bash
bin/rails db:test:prepare   # sync test database with schema
bundle exec rspec           # run test suite (must pass before finishing work)
bundle exec rubocop         # Rails Omakase style (must pass)
bundle exec i18n-tasks health       # no missing/unused/inconsistent translations
bundle exec i18n-tasks check-normalized  # locale files sorted/normalized
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
| `app/policies/` | Pundit authorization per resource |
| `app/controllers/dashboards_controller.rb` | Staff dashboard; redirects participants to their progress page |
| `app/views/layouts/application.html.erb` | Portal shell (drawer sidebar + navbar) |
| `app/views/layouts/devise.html.erb` | Centered card layout for sign-in/up pages |
| `db/migrate/`, `db/schema.rb` | Schema with FKs and composite unique indexes |
| `spec/` | `models/`, `policies/`, `requests/`, `data/`, `factories.rb` |

Domain relationships:

```text
User --OrganizationMembership--> Organization --< Program --< Unit
User --UnitAttendance--> Unit --UnitCoverage--> Content
```

## Non-Negotiable Domain Rules

1. **A Unit is a one-off real-world event.** Never introduce
   `UnitOccurrence`, unit templates, or recurring instances. Units always
   belong to a `Program` (`schooling` / `freizeit`); programs own the
   `organization_id`.
2. **Coverage is derived, never stored.** Do not add cached
   `covered`/`completed` columns or callbacks that write them. Whether a
   unit covers a content item is computed by `Unit#covers?` (a direct
   `UnitCoverage` link, or a link on an ancestor in the `Content`
   hierarchy). Attendance truth lives on `UnitAttendance#status`.
3. **Only `attended` attendance counts as completed participation.**
   Registered/cancelled/no_show never count.
4. **Content is data, not code.** Never hard-code content titles or the
   level → section → detail hierarchy in Ruby. The hierarchy lives in the
   database (seeded from `db/seeds_data/contents.json`).
5. **Database integrity mirrors validations:** unique indexes on
   `[user_id, unit_id]`, `[unit_id, content_id]`,
   `[user_id, organization_id]`; use foreign keys. Add both validation *and*
   constraint for new invariants.
6. `Content` hierarchy rules: `level` has no parent, `section` belongs to
   exactly one `level`, `detail` belongs to exactly one `section` and has no
   children. Enforced by `Content#hierarchy_rules` validation (see
   `app/models/content.rb:46`); do not bypass it.
7. Future concepts (`QualificationEvidence`, `RequirementSet`, certificates…)
   stay unimplemented until a requirement explicitly asks.

## Authorization

Two system roles on `User.role`: `user` (default) and `admin`. Organizing
authority is per-organization via `OrganizationMembership.role`
(`member` < `organiser`). Participation in units is represented only by
`UnitAttendance` — any user can attend, including organisers.

- Every portal controller inherits `BaseController` (enforces sign-in).
- Every action calls `authorize`; collections call `policy_scope`.
- Matrix: plain users browse programs/units + own progress; organisers manage
  programs, units, attendance and rosters **of their own organizations only**
  (`user.organises?(organization)`); admins manage organizations, programs,
  users and deletions. The staff dashboard is visible to
  admins and organisers; everyone else lands on their progress page.
- Program forms must limit organization options to permitted ones; the
  controller clamps `organization_id` server-side for non-admins (see
  `ProgramsController#ensure_permitted_organization`). Unit forms must limit
  program options likewise (`UnitsController#ensure_permitted_program`).
  Keep those clamps when refactoring program/unit create/update.
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
- The central domain scenario (guide §13: covering a level implies its
  sections and details; covering a section implies its details but not
  siblings or ancestors) has specs in `spec/models/unit_covers_spec.rb`,
  and the attendance list has an end-to-end version in
  `spec/requests/user_progress_spec.rb`. Keep them passing through any
  refactor.

## UI Conventions

- DaisyUI components only when a suitable component exists (navbar, drawer,
  menu, table, badge, stat, progress, alert, modal, fieldset…). Tailwind
  utilities for layout/spacing. No second design system, no custom lookalikes.
- Classic admin-portal layout: persistent drawer sidebar on desktop,
  collapsible on mobile; active nav item gets `menu-active`.
- Sidebar entries are role-filtered via policies (see
  `ApplicationHelper#portal_nav_items`).
- Flash messages render through `shared/_flash` as DaisyUI alerts.
- Status colors: attendance badges via `attendance_status_badge_class`,
  coverage badges via `badge-ghost`/`badge-primary`/`badge-secondary` per
  content type; dashboard stats via `stat`.

## I18n Conventions

- Default locale is `:de`, also supported: `:en`
  (`config.i18n.available_locales`). User language is stored on
  `User#locale` and resolved as
  `params > user > session > Accept-Language > default` (see
  `ApplicationController#set_locale`).
- **All new UI text must be translatable.** Never hard-code user-facing
  strings in views, controllers, helpers, or mailers. Use lazy `t(".key")`
  in views, scoped `t(".key")` in controllers, `human_enum_label` for
  enums, and `l()` for dates/times. User-entered data (names, descriptions,
  `Content.title`) stays untranslated.
- Locale files: `config/locales/en.yml` / `de.yml` for app strings,
  `config/locales/activerecord.en/de.yml` for models/attributes/enums/errors.
  `rails-i18n` + `devise-i18n` own framework strings; app config lives in
  `config/i18n-tasks.yml` (`base_locale: de`).
- Pluralization via `one`/`other` hashes (never bare `%{count}` singulars);
  keep EN/DE key trees identical.

## Gotchas

- **Routes:** Devise is mounted at `/auth` (`devise_for :users, path: "auth"`).
  This frees `/users/*` for the admin `UsersController` — mounting Devise back
  on default paths makes `POST /users` hit registrations instead of
  `UsersController#create`.
- **Nested attributes:** e.g. `organization_memberships_attributes` requires
  `params.require(:user).permit(...)`; `params.expect` silently drops the
  dynamic `"0"` wrapper keys. Use require+permit for nested forms.
- Array params need array permits: `organization_ids: []`, not
  `:organization_ids`.
- Use `:unprocessable_content` (not the deprecated `:unprocessable_entity`).
- After schema changes run `bin/rails db:migrate && bin/rails db:test:prepare`
  so request specs don't fail on stale test schema.

## Definition of Done

1. `bundle exec rspec` — all green
2. `bundle exec rubocop` — no offenses
3. `bundle exec i18n-tasks health` — no missing/unused/inconsistent translations
4. `bundle exec i18n-tasks check-normalized` — locale files normalized
5. All new UI text translatable (EN + DE keys, lazy `t(".key")`, no hard-coded
   user-facing strings; specs assert via `I18n.t`, never literals)
6. New behavior covered by specs (model/policy/request/data as fitting)
7. Every controller action has at least one spec asserting its response
   status (render or redirect) — including GET pages that only render forms
8. Migrations reversible; schema.rb committed alongside
