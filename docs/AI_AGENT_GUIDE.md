# AI Agent Implementation Guide

## Purpose

You are implementing the Juleica Progress Tracker described in
`PRODUCT_REQUIREMENTS.md`.

Read that document before making architectural or implementation
decisions.

The application is a Rails application for several cooperating churches
that offer training programs (schoolings, freizeiten) made of unique,
one-off units. The system records attendance and which content each
unit covers, so organisers can see what training a person has
completed.

The goal is to build a clean, conventional Rails application with a
domain model that is easy to extend.

------------------------------------------------------------------------

# 1. Core Domain Model

Implement these models first:

-   `User`
-   `Organization`
-   `OrganizationMembership`
-   `Program` (`schooling` or `freizeit`, owns the `organization_id`)
-   `Unit` (one session inside a program)
-   `UnitAttendance`
-   `UnitCoverage`
-   `Content` (level → section → detail hierarchy)

The relationship is:

``` text
User
  |
  +-- OrganizationMembership --> Organization --< Program --< Unit
  |                                                  |
  +-- UnitAttendance ---------> Unit --UnitCoverage--> Content
```

Do NOT introduce `UnitOccurrence`.

A `Unit` is already a unique, one-off event.

Do NOT introduce a reusable unit template unless a future requirement
explicitly asks for it.

------------------------------------------------------------------------

# 2. Program and Unit Semantics

A program groups several units. It represents a schooling or a freizeit
(`Program.kind`: `schooling` / `freizeit`) and owns the `organization_id`.

Expected program fields include:

``` text
name
description
kind
organization_id
```

A unit represents an actual event: one session inside a program.

Expected unit fields include:

``` text
name
description
starts_at
ends_at
location
program_id
```

A unit can be completely different from every other unit. Units always
belong to exactly one program; the organization is derived via
`unit.program.organization` (there is no `organization_id` on units).

Do not assume:

-   recurring units
-   yearly unit instances
-   a fixed unit curriculum
-   fixed topics
-   a fixed set of contents

------------------------------------------------------------------------

# 3. Unit Coverage

Use a join model:

``` text
UnitCoverage
  unit_id
  content_id
```

This is intentionally a real model rather than
`has_and_belongs_to_many`.

Why:

A unit can cover multiple content items, and the same content item can
be covered by many different units.

Covering a level or section automatically covers everything below it.
That implication is computed, not stored — see `Unit#covers?` (§6).

Use conventional Rails associations:

``` ruby
class Unit < ApplicationRecord
  belongs_to :program

  has_many :unit_attendances, dependent: :destroy
  has_many :users, through: :unit_attendances

  has_many :unit_coverages, dependent: :destroy
  has_many :covered_contents,
           through: :unit_coverages,
           source: :content
end
```

and:

``` ruby
class UnitCoverage < ApplicationRecord
  belongs_to :unit
  belongs_to :content

  validates :content_id, uniqueness: { scope: :unit_id }
end
```

Add a unique database index on:

``` text
unit_id + content_id
```

------------------------------------------------------------------------

# 4. Attendance

Use:

``` text
UnitAttendance
  user_id
  unit_id
  status
```

Suggested enum:

``` ruby
enum :status, {
  registered: 0,
  attended: 1,
  cancelled: 2,
  no_show: 3
}
```

Only `attended` counts as completed participation. Registered,
cancelled and no-show attendances never count.

Add a unique database index on:

``` text
user_id + unit_id
```

Do not use a plain HABTM relationship for attendance.

Attendance is important domain data.

------------------------------------------------------------------------

# 5. Content Hierarchy

Use:

``` text
Content
  parent_id (self-reference, null for levels)
  title
  content_type (level / section / detail)
  position
```

Content forms a strict three-level hierarchy:

``` text
level (no parent)
  section (exactly one level parent)
    detail (exactly one section parent, no children)
```

Do not hard-code content titles or the hierarchy in Ruby.

Content lives in the database. It is seeded from
`db/seeds_data/contents.json` (via `db:seed` and the
`ImportJuleicaContents` data migration) and validated by
`Content#hierarchy_rules`: levels must not have parents or detail
children, sections require a level parent and may only have detail
children, details require a section parent and must not have children.

------------------------------------------------------------------------

# 6. Coverage Must Be Derived

Do NOT add:

``` text
unit_content.completed
```

Coverage is derived from:

1.  The unit's direct `UnitCoverage` links.
2.  Links on ancestors in the `Content` hierarchy: covering a level
    covers its sections and details; covering a section covers its
    details but not siblings or ancestors.

Conceptually (`Unit#covers?`):

``` text
covers?(level) =
  unit_coverages.exists?(content_id: level.id)

covers?(section) =
  unit_coverages.exists?(content_id: [section.id, section.parent_id])

covers?(detail) =
  unit_coverages.exists?(content_id: [detail.id, section.id, level.id])
```

Avoid duplicating this result in the database unless there is a
demonstrated performance requirement.

------------------------------------------------------------------------

# 7. Coverage API / Domain Interface

The domain-level interface for coverage is `Unit#covers?(content)`.

For example:

``` ruby
unit.covers?(level)    # true when the level itself is linked
unit.covers?(section)  # true when the section or its level is linked
unit.covers?(detail)   # true when the detail, its section, or its level is linked
```

The interface returns booleans only — there are no hours, no earned /
remaining totals, and no service object. A user's page (`users#show`)
lists their `UnitAttendance` records with statuses instead of a
computed progress total.

Do not over-engineer this. Keep the check on the model where it is
testable (`spec/models/unit_covers_spec.rb`).

------------------------------------------------------------------------

# 8. Upcoming Units

The units index offers `upcoming` / `past` / `all` tabs backed by the
`Unit.upcoming` and `Unit.past` scopes (ordered by `starts_at` /
`ends_at`).

A future version may answer which upcoming units cover content a user
has not attended yet, derived from:

``` text
unattended content
        +
future units
        +
unit coverages
```

The current implementation does not need a recommendation engine.

A simple query/filter is sufficient.

------------------------------------------------------------------------

# 9. Organizations

Model cooperating churches as organizations.

Use:

``` text
Organization
  id
  name
```

Users may belong to multiple organizations over time, so use:

``` text
OrganizationMembership
  user_id
  organization_id
```

Do not put a permanent `organization_id` directly on `User` unless a
future requirement explicitly establishes that a user can belong to
exactly one organization.

Programs belong to organizations (`Program belongs_to :organization`,
`kind`: `schooling` / `freizeit`). Units belong to programs and reach
their organization via `unit.program.organization` — there is no
`organization_id` on units. Authorization for programs and units is
scoped to the program's organization (see `ProgramPolicy`,
`UnitPolicy`).

------------------------------------------------------------------------

# 10. Database Integrity

Use database constraints in addition to Rails validations.

Required unique indexes:

``` text
unit_attendances:
  [user_id, unit_id]

unit_coverages:
  [unit_id, content_id]

organization_memberships:
  [user_id, organization_id]
```

Use foreign keys.

Use appropriate timestamps.

Cross-table rules that the database cannot express (hierarchy rules,
`ends_at` after `starts_at`) live in model validations plus request
specs — see `spec/models/content_spec.rb` and
`spec/models/unit_spec.rb`.

------------------------------------------------------------------------

# 11. Rails Conventions

Prefer conventional Rails:

-   Active Record associations
-   migrations
-   validations
-   scopes where useful
-   enums for finite state
-   service objects only where they clarify domain behavior
-   database constraints for invariants

Avoid:

-   unnecessary repository layers
-   unnecessary generic CRUD abstractions
-   premature event sourcing
-   unnecessary polymorphism
-   generic "Entity" models
-   a large service-object architecture

Keep the domain boring and explicit.

Boring is good here.

------------------------------------------------------------------------

# 12. Testing Requirements

Write model and domain tests for at least these cases.

### Attendance

-   A user can attend a unit.
-   A user cannot have duplicate attendance for the same unit.
-   Attendance defaults to `registered`.
-   All four statuses (`registered`, `attended`, `cancelled`, `no_show`)
    are accepted; only `attended` counts as completed participation.

### Unit coverage

-   A unit can cover multiple contents.
-   A content item can be covered by multiple units.
-   Duplicate unit/content combinations are prevented (validation and
    unique index).

### Coverage derivation (`Unit#covers?`)

Test:

``` text
link level        -> covers level, its sections and its details
link section      -> covers section and its details, but not siblings,
                     the parent level, or other sections
link detail       -> covers only that detail
no link           -> covers nothing; nil content -> false
```

And make sure ancestor links imply descendants, never the reverse.

------------------------------------------------------------------------

# 13. Important Domain Test

This scenario should be explicitly covered (see
`spec/models/unit_covers_spec.rb`):

``` text
Hierarchy:
Level 1
  Section 1.1
    Detail 1.1.1, Detail 1.1.2
  Section 1.2
    Detail 1.2.1

Unit links Level 1 and nothing else.

Result:
covers Level 1, Section 1.1, Section 1.2 and all details.
```

And the reverse direction:

``` text
Unit links Detail 1.1.1 and nothing else.

Result:
covers only Detail 1.1.1 — not Section 1.1, not Level 1,
not Detail 1.1.2.
```

This is central to the application.

------------------------------------------------------------------------

# 14. UI Priorities

The most useful UI is not a generic list of units.

Prioritize:

## User attendance

Show (see `users#show`):

-   the user's unit attendances with statuses
-   links to the attended units

## Program

Show (see `programs#show`):

-   name, kind (`schooling` / `freizeit`), organization
-   description
-   the program's units

## Unit

Show (see `units#show`):

-   date/time
-   program and organization
-   location
-   description
-   covered contents
-   coverage manager (add/remove links per hierarchy node)
-   attendees (organisers of the program's organization only)

## Organiser overview

Allow an organiser to quickly answer:

-   Who attended this unit?
-   What does this unit cover?
-   Which units belong to this program?

------------------------------------------------------------------------

# 15. Avoid Hard-Coding Official Juleica Rules

The application should track configured content.

Do not embed assumptions such as:

``` ruby
REQUIRED_MODULES = [...]
```

or:

``` ruby
if user.unit_count >= 5
```

The content hierarchy should live in the database.

If official requirements change in the future, the data model should be
able to adapt without rewriting the core domain logic.

------------------------------------------------------------------------

# 16. Future Features --- Do Not Implement Yet Unless Requested

Potential future concepts include:

``` text
QualificationEvidence
FirstAidCertificate
RequirementSet
RequirementVersion
ExternalTraining
ManualCredit
Certificate
```

These are intentionally outside the initial MVP.

Do not introduce them simply because they might eventually be useful.

The current system should first establish a solid:

``` text
User
  -> Attendance
  -> Unit
  -> UnitCoverage
  -> Content
```

flow.

------------------------------------------------------------------------

# 17. Suggested Implementation Order

Implement in this order:

1.  Organizations
2.  Organization memberships
3.  Content hierarchy (levels, sections, details)
4.  Programs
5.  Units
6.  Unit coverage
7.  Unit attendance
8.  Tests for coverage derivation
9.  Program/unit/user administration UI
10. User attendance UI
11. Upcoming-unit filtering

Keep commits and changes focused.

After each major domain model, run the test suite.

------------------------------------------------------------------------

# 18. Acceptance Criteria

The implementation is successful when this scenario works end-to-end:

``` text
1. Admin creates the "Youth Leadership Program 2026" program
   (kind: schooling) for St. Martin's.

2. Admin creates the "Youth Leadership Weekend 2026" unit in that
   program. It covers the "Group Leadership" content level.

3. Alice is registered for the unit.

4. Alice's attendance is marked "attended".

5. Alice's page lists:
   Youth Leadership Weekend 2026 — Attended.

6. The unit page shows the covered contents, and `unit.covers?`
   returns true for the level, its sections and its details.
```

The application should make it possible to trace coverage back to the
actual unit attendance and coverage records.

------------------------------------------------------------------------

# 19. Guiding Principle

The system should answer:

> **What training has this person actually completed, and what
> content did that training cover?**

Keep that question at the center of architectural decisions.

If a proposed feature does not help answer that question or support
administration of the underlying data, question whether it belongs in
the MVP.

# 20. UI/UX Requirements

The application should use a classic portal-style administration interface.

## DaisyUI

Always use DaisyUI components for UI elements whenever a suitable DaisyUI component exists.

Prefer DaisyUI components such as:

- `navbar`
- `menu`
- `drawer`
- `card`
- `table`
- `badge`
- `button`
- `alert`
- `modal`
- `dropdown`
- `tabs`
- `breadcrumbs`
- `progress`
- `stat`
- `form-control`
- `input`
- `select`
- `textarea`

Do not create custom UI components when an appropriate DaisyUI component already exists.

Keep styling consistent with the DaisyUI design system and use Tailwind utilities for layout and spacing where appropriate.

## Portal Layout

The application should use a classic portal/dashboard layout rather than a marketing-site layout.

The primary layout should consist of:

```text
┌──────────────────────────────────────────────────────────────┐
│ Header / Top Bar                                             │
├───────────────┬──────────────────────────────────────────────┤
│               │                                              │
│ Side          │ Main Content                                 │
│ Navigation    │                                              │
│               │                                              │
│ Dashboard     │                                              │
│ Users         │                                              │
│ Programs      │                                              │
│ Units         │                                              │
│ Organizations │                                              │
│               │                                              │
│               │                                              │
└───────────────┴──────────────────────────────────────────────┘
```

Use a responsive DaisyUI drawer for the application shell so that:

On desktop, the sidebar is persistently visible.
On smaller screens, the sidebar can be opened/closed.
The main content area remains the primary focus.
Navigation clearly indicates the current section.
Side Navigation

The main navigation should initially contain:

Dashboard
Users
Programs
Units
Organizations

Additional navigation items may be added as features are introduced.

The navigation should use DaisyUI's menu component.

The active navigation item should be visually highlighted.

Dashboard / Portal Style

The dashboard should prioritize information and actions over decorative design.

Use DaisyUI components such as:

stat for high-level numbers (users, upcoming units, content items)
card for grouped information
table for lists
badge for statuses
alert for important information

For example, the dashboard shows:
```text
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ Users            │ │ Upcoming Units   │ │ Content Items    │
│ 124              │ │ 3                │ │ 12               │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

Recent Units
───────────────────────────────────────────────────────────────
Unit                           Date          Attendees
Youth Leadership Weekend       12 Oct        18
Safeguarding Weekend           02 Nov        14
User Attendance UI

The user page should make attendance immediately understandable.

Use DaisyUI badge, card, and table components where appropriate.

Show the user's unit attendances with statuses:

Unit Attendance
───────────────────────────────────────────────────────────────
Youth Leadership Weekend       Attended
Safeguarding Weekend           Registered

The interface should make it easy to understand which units a user
attended and what each unit covers (see the unit page's "Covers"
section and the coverage manager).
General UI Principle

The application is an administrative portal.

Prefer:

clear information hierarchy
dense but readable data presentation
tables for administrative data
cards for summaries
consistent navigation
predictable forms
obvious primary actions
responsive behavior

Avoid:

marketing-page layouts
oversized hero sections
unnecessary animations
highly decorative interfaces
introducing a second component/design system
custom components when DaisyUI already provides the required component

The UI should feel like a classic, well-designed administration portal, not a marketing website.