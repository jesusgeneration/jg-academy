# jg-academy

A Rails application for a network of cooperating churches that offer
training programs (schoolings, freizeiten) made of one-off units. The
application tracks unit attendance and derives each person's progress
toward the requirements for obtaining a Juleica card.

It is a **progress and evidence tracker**, not a booking system and not a
replacement for the official Juleica application process:

> What training has this person actually completed, what Juleica requirements
> did that training contribute toward, and what do they still need?

## Core Domain

Every `Unit` is a unique, one-off real-world event (no recurring instances,
no templates) belonging to a `Program` (`schooling` or `freizeit`).
Units cover configurable `Content` items through `UnitCoverage`. Users attend units
via `UnitAttendance`; only the `attended` status earns credit. Progress is
always **derived** from attendance — it is never stored.

```text
User
  |
  +-- OrganizationMembership --> Organization --< Program --< Unit
  |
  +-- UnitAttendance -------> Unit
                                  |
                                  +-- UnitCoverage --> Content
```

## Roles & Authorization

System privilege lives on the user; organizing authority lives on the
organization membership. Participation in training is represented solely by
`UnitAttendance` — anyone can attend a unit, including organisers.

| Context | Values | Meaning |
| ------- | ------ | ------- |
| `User.role` | `user` / `admin` | Admins manage organizations, programs, users and deletions |
| `OrganizationMembership.role` | `member` / `organiser` | Organisers manage their church's programs, units, attendance and rosters |

```text
Alice
  User.role = user
  OrganizationMembership
    Church A -> organiser
    Church B -> member
  UnitAttendance
    Juleica Weekend -> attended
```

Authorization is enforced with [Pundit](https://github.com/varvet/pundit)
(`app/policies/`). Program and unit management rights are scoped to the program's
organization: an organiser of Church A cannot edit Church B's programs or units or see
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

`bin/rails db:seed` creates a demo dataset (organizations, memberships,
programs, units with content coverage, and attendances):

| Account                  | Password      | Notes                                    |
| ------------------------ | ------------- | ---------------------------------------- |
| `admin@example.com`      | `password123` | admin                                    |
| `organiser@example.com`  | `password123` | organiser at St. Martin's, also attends  |
| `alice@example.com`      | `password123` | member, attends two units                |
| `bob@example.com`        | `password123` | member                                   |

Sign in at `/auth/sign_in`.

## Testing

RSpec with FactoryBot (model, policy, data and request specs):

```bash
bin/rails db:test:prepare
bundle exec rspec
```

Rubocop (Rails Omakase style) must pass as well:

```bash
bundle exec rubocop
```

## Troubleshooting

### `db:drop` fails with `PG::ObjectInUse`

Dropping the database can fail with `database "..." is being accessed by
other users` when another process still holds a connection — typically the
Ruby language server, a Rails console, or the dev server. Terminate the other
backends first (they reconnect on their own), then drop:

```bash
bin/rails runner 'ActiveRecord::Base.connection.execute("SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = current_database() AND pid <> pg_backend_pid()")'
bin/rails db:drop db:create db:migrate:with_data db:seed
```

## Key Conventions

- Coverage is derived, never stored: `Unit#covers?` checks for a direct
  `UnitCoverage` link or a link on an ancestor in the `Content` hierarchy.
  Never persist coverage results or completion flags.
- Content lives in the database (seeded from `db/seeds_data/contents.json`
  via `db:seed` / the `ImportJuleicaContents` data migration); no content
  titles or hierarchy rules are hard-coded.
- UI uses DaisyUI components exclusively (portal layout with drawer sidebar);
  see `docs/AI_AGENT_GUIDE.md` §20.
- Database integrity (unique indexes, foreign keys)
  mirrors application validations.

See `docs/PRODUCT_REQUIREMENTS (1).md` for the full product specification and
`docs/AI_AGENT_GUIDE.md` for implementation guidance.

## Deployment

Standard Rails 8 setup with Kamal (`config/deploy.yml`), Solid Queue/Cache/
Cable in production, Thruster in front of Puma.
