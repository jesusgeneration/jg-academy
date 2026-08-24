# AI Agent Implementation Guide

## Purpose

You are implementing the Juleica Progress Tracker described in
`PRODUCT_REQUIREMENTS.md`.

Read that document before making architectural or implementation
decisions.

The application is a Rails application for several cooperating churches
that offer unique, one-off training events. The system records
attendance and calculates how much of each configured Juleica
requirement a person has accumulated.

The goal is to build a clean, conventional Rails application with a
domain model that is easy to extend.

------------------------------------------------------------------------

# 1. Core Domain Model

Implement these models first:

-   `User`
-   `Organization`
-   `OrganizationMembership`
-   `Course`
-   `CourseAttendance`
-   `CourseRequirement`
-   `JuleicaRequirement`

The relationship is:

``` text
User
  |
  +-- OrganizationMembership --> Organization
  |
  +-- CourseAttendance -------> Course
                                  |
                                  +-- CourseRequirement --> JuleicaRequirement
```

Do NOT introduce `CourseOccurrence`.

A `Course` is already a unique, one-off event.

Do NOT introduce a reusable course template unless a future requirement
explicitly asks for it.

------------------------------------------------------------------------

# 2. Course Semantics

A course represents an actual event.

Expected fields include:

``` text
name
description
starts_at
ends_at
location
organization_id
```

A course can be completely different from every other course.

Do not assume:

-   recurring courses
-   yearly course instances
-   a fixed course curriculum
-   fixed topics
-   a fixed set of requirements

------------------------------------------------------------------------

# 3. Course Requirements

Use a join model:

``` text
CourseRequirement
  course_id
  juleica_requirement_id
  hours
```

This is intentionally a real model rather than
`has_and_belongs_to_many`.

Why:

A course can contribute different amounts of training time to different
requirements.

Example:

``` text
Course A
  Group Leadership: 4 hours
  Legal Foundations: 2 hours
  Child Protection: 2 hours
```

Use conventional Rails associations:

``` ruby
class Course < ApplicationRecord
  belongs_to :organization

  has_many :course_attendances, dependent: :destroy
  has_many :users, through: :course_attendances

  has_many :course_requirements, dependent: :destroy
  has_many :juleica_requirements, through: :course_requirements
end
```

and:

``` ruby
class CourseRequirement < ApplicationRecord
  belongs_to :course
  belongs_to :juleica_requirement

  validates :hours, numericality: { greater_than: 0 }
end
```

Add a unique database index on:

``` text
course_id + juleica_requirement_id
```

------------------------------------------------------------------------

# 4. Attendance

Use:

``` text
CourseAttendance
  user_id
  course_id
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

Only `attended` contributes qualification credit in the initial
implementation.

Add a unique database index on:

``` text
user_id + course_id
```

Do not use a plain HABTM relationship for attendance.

Attendance is important domain data.

------------------------------------------------------------------------

# 5. Juleica Requirements

Use:

``` text
JuleicaRequirement
  name
  description
  required_hours
```

Do not hard-code requirements in Ruby.

Requirements must be stored in the database.

The model should validate that `required_hours` is positive.

Do not assume that all requirements have the same required number of
hours.

------------------------------------------------------------------------

# 6. Progress Must Be Derived

Do NOT add:

``` text
user_juleica_requirement.completed
```

for the initial implementation.

Completion is derived from:

1.  The user's qualifying course attendance.
2.  The requirements covered by those courses.
3.  The hours contributed by those courses.
4.  The requirement's required hours.

Conceptually:

``` text
earned_hours =
  sum(course_requirement.hours)
  for courses the user attended
  for the selected requirement
```

Then:

``` text
remaining_hours =
  max(required_hours - earned_hours, 0)
```

and:

``` text
completed =
  earned_hours >= required_hours
```

Avoid duplicating this result in the database unless there is a
demonstrated performance requirement.

------------------------------------------------------------------------

# 7. Progress API / Domain Interface

Create a clean domain-level interface for retrieving progress.

For example, the application may expose something conceptually like:

``` ruby
user.juleica_progress
```

The result should provide:

``` text
requirement
required_hours
earned_hours
remaining_hours
completed
```

A service object is acceptable if that produces cleaner code.

For example:

``` text
JuleicaProgress
JuleicaProgressCalculator
```

Do not over-engineer this. Choose the simplest design that keeps the
calculation testable.

------------------------------------------------------------------------

# 8. Upcoming Course Recommendations

The application should eventually answer:

> Which upcoming courses could help this user complete their remaining
> requirements?

This can be derived from:

``` text
remaining requirements
        +
future courses
        +
course requirements
```

For example:

``` text
Alice is missing:

Youth Work Methods: 4 hours

Upcoming:
Youth Work Weekend
  Youth Work Methods: 6 hours
```

The first implementation does not need a sophisticated recommendation
engine.

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

------------------------------------------------------------------------

# 10. Database Integrity

Use database constraints in addition to Rails validations.

Required unique indexes:

``` text
course_attendances:
  [user_id, course_id]

course_requirements:
  [course_id, juleica_requirement_id]

organization_memberships:
  [user_id, organization_id]
```

Use foreign keys.

Prevent negative hours at the application level and, where practical, at
the database level.

Use appropriate timestamps.

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

-   A user can attend a course.
-   A user cannot have duplicate attendance for the same course.
-   Registered attendance does not contribute hours.
-   Attended attendance contributes hours.
-   Cancelled attendance does not contribute hours.
-   No-show attendance does not contribute hours.

### Course requirements

-   A course can cover multiple requirements.
-   A requirement can be covered by multiple courses.
-   A course can contribute different hours to different requirements.
-   Duplicate course/requirement relationships are prevented.
-   Hours must be positive.

### Progress

Test:

``` text
0 hours -> incomplete
4 / 8 -> incomplete, 4 remaining
8 / 8 -> complete
10 / 8 -> complete, 0 remaining
```

Also test accumulation across multiple courses:

``` text
Course A -> 4 hours
Course B -> 4 hours
Requirement -> 8 hours

Result -> complete
```

And make sure attendance status affects the calculation.

------------------------------------------------------------------------

# 13. Important Domain Test

This scenario should be explicitly covered:

``` text
Requirement:
Group Leadership = 8 hours

Course A:
Group Leadership = 4 hours

Course B:
Group Leadership = 4 hours

User attends Course A.
User does NOT attend Course B.

Result:
4 / 8 hours
Incomplete.
```

Then when Course B attendance becomes `attended`:

``` text
8 / 8 hours
Complete.
```

This is central to the application.

------------------------------------------------------------------------

# 14. UI Priorities

The most useful UI is not a generic list of courses.

Prioritize:

## User progress

Show:

-   completed requirements
-   partial requirements
-   remaining hours
-   upcoming courses relevant to missing requirements

## Course

Show:

-   date/time
-   organization
-   location
-   description
-   requirements covered
-   hours contributed to each requirement
-   attendees

## Admin progress

Allow an administrator to quickly answer:

-   Who attended this course?
-   What did this course count toward?
-   What is Alice still missing?
-   Which users are close to completing their requirements?

------------------------------------------------------------------------

# 15. Avoid Hard-Coding Official Juleica Rules

The application should track configured requirements.

Do not embed assumptions such as:

``` ruby
REQUIRED_MODULES = [...]
```

or:

``` ruby
if user.course_count >= 5
```

The requirement set should live in the database.

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
  -> Course
  -> CourseRequirement
  -> JuleicaRequirement
```

flow.

------------------------------------------------------------------------

# 17. Suggested Implementation Order

Implement in this order:

1.  Organizations
2.  Organization memberships
3.  Juleica requirements
4.  Courses
5.  Course requirements
6.  Course attendance
7.  Progress calculation
8.  Tests for progress
9.  Course/user administration UI
10. User progress UI
11. Upcoming-course filtering

Keep commits and changes focused.

After each major domain model, run the test suite.

------------------------------------------------------------------------

# 18. Acceptance Criteria

The implementation is successful when this scenario works end-to-end:

``` text
1. Admin creates "Group Leadership" requirement.
   Required hours: 8.

2. Admin creates "Youth Leadership Weekend".
   It contributes 4 hours to Group Leadership.

3. Alice is registered for the course.

4. Alice's attendance is marked "attended".

5. Alice's progress shows:
   Group Leadership: 4 / 8 hours
   Remaining: 4 hours
   Status: incomplete.

6. Admin creates another course.

7. The second course contributes another 4 hours to Group Leadership.

8. Alice attends the second course.

9. Alice's progress now shows:
   Group Leadership: 8 / 8 hours
   Remaining: 0 hours
   Status: complete.
```

The application should make it possible to trace the 8 hours back to the
two actual course attendances.

------------------------------------------------------------------------

# 19. Guiding Principle

The system should answer:

> **What training has this person actually completed, what Juleica
> requirements did that training contribute toward, and what do they
> still need?**

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
│ Courses       │                                              │
│ Requirements  │                                              │
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
Courses
Juleica Requirements
Organizations

Additional navigation items may be added as features are introduced.

The navigation should use DaisyUI's menu component.

The active navigation item should be visually highlighted.

Dashboard / Portal Style

The dashboard should prioritize information and actions over decorative design.

Use DaisyUI components such as:

stat for high-level numbers
card for grouped information
table for lists
badge for statuses
progress for Juleica progress
alert for important information

For example, the dashboard might show:
```text
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ Users            │ │ Upcoming Courses │ │ Requirements     │
│ 124              │ │ 3                │ │ 12               │
└──────────────────┘ └──────────────────┘ └──────────────────┘
```

Recent Courses
───────────────────────────────────────────────────────────────
Course                         Date          Attendees
Youth Leadership Weekend       12 Oct        18
Safeguarding Weekend           02 Nov        14

Users Close to Juleica
───────────────────────────────────────────────────────────────
Alice                           9 / 10
Bob                             8 / 10
Charlie                         8 / 10
User Progress UI

The user progress page should make Juleica progress immediately understandable.

Use DaisyUI progress, badge, card, and table components where appropriate.

For each requirement show:

Group Leadership
8 / 8 hours                         ✓ Complete

Youth Work Methods
4 / 8 hours                         4 hours remaining

The interface should make it easy to understand why a user has received credit.

Where useful, show the courses contributing to a requirement:

Youth Work Methods
4 / 8 hours

Youth Leadership Weekend
+ 2 hours

Games & Group Work Weekend
+ 2 hours
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