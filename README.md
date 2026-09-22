# jg-academy

A Rails application for a network of cooperating churches that offer one-off
training weekends and courses. The application tracks course attendance and
derives each person's progress toward the requirements for obtaining a Juleica
card.

It is a **progress and evidence tracker**, not a booking system and not a
replacement for the official Juleica application process:

> What training has this person actually completed, what Juleica requirements
> did that training contribute toward, and what do they still need?

## Core Domain

Every `Course` is a unique, one-off real-world event (no recurring instances,
no templates). Courses contribute configurable hours to configurable
`JuleicaRequirement` records through `CourseRequirement`. Users attend courses
via `CourseAttendance`; only the `attended` status earns credit. Progress is
always **derived** from attendance — it is never stored.

```text
User
  |
  +-- OrganizationMembership --> Organization
  |
  +-- CourseAttendance -------> Course
                                  |
                                  +-- CourseRequirement --> JuleicaRequirement
```

## Roles & Authorization

System privilege lives on the user; organizing authority lives on the
organization membership. Participation in training is represented solely by
`CourseAttendance` — anyone can attend a course, including organisers.

| Context | Values | Meaning |
| ------- | ------ | ------- |
| `User.role` | `user` / `admin` | Admins manage organizations, Juleica requirements, users and deletions |
| `OrganizationMembership.role` | `member` / `organiser` | Organisers manage their church's courses, attendance and rosters |

```text
Alice
  User.role = user
  OrganizationMembership
    Church A -> organiser
    Church B -> member
  CourseAttendance
    Juleica Weekend -> attended
```

Authorization is enforced with [Pundit](https://github.com/varvet/pundit)
(`app/policies/`). Course management rights are scoped to the course's
organization: an organiser of Church A cannot edit Church B's courses or see
their attendee rosters. New accounts default to `user`; admins assign
membership roles on the user edit form.

## Setup

Requirements: Ruby (see `.ruby-version`), PostgreSQL, Node not required
(importmap + Propshaft).

```bash
bundle install
bin/rails db:setup          # creates DB, loads schema, runs seeds
bin/dev                     # starts Rails + Tailwind watcher
```

### Seed data

`bin/rails db:seed` creates a demo dataset reproducing the acceptance scenario
from the product requirements (two courses accumulating 8/8 hours of "Group
Leadership" for Alice):

| Account                  | Password      | Notes                                    |
| ------------------------ | ------------- | ---------------------------------------- |
| `admin@example.com`      | `password123` | admin                                    |
| `organiser@example.com`  | `password123` | organiser at St. Martin's, also attends  |
| `alice@example.com`      | `password123` | member, 8/8 Group Leadership             |
| `bob@example.com`        | `password123` | member                                   |

Sign in at `/auth/sign_in`.

## Testing

RSpec with FactoryBot (model, service, policy and request specs):

```bash
bin/rails db:test:prepare
bundle exec rspec
```

Rubocop (Rails Omakase style) must pass as well:

```bash
bundle exec rubocop
```

## Key Conventions

- Progress is calculated by `JuleicaProgressCalculator`
  (`app/services/juleica_progress_calculator.rb`) and exposed via
  `User#juleica_progress`. Never persist earned hours or completion flags.
- Requirements live in the database; no official Juleica rules are hard-coded.
- UI uses DaisyUI components exclusively (portal layout with drawer sidebar);
  see `docs/AI_AGENT_GUIDE.md` §20.
- Database integrity (unique indexes, foreign keys, check constraints)
  mirrors application validations.

See `docs/PRODUCT_REQUIREMENTS (1).md` for the full product specification and
`docs/AI_AGENT_GUIDE.md` for implementation guidance.

## Deployment

Standard Rails 8 setup with Kamal (`config/deploy.yml`), Solid Queue/Cache/
Cable in production, Thruster in front of Puma.
