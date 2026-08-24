# Juleica Progress Tracker --- Product Requirements Document

## 1. Product Overview

This application is a Rails application for a network of churches that
jointly offer one-off training weekends and courses that can contribute
toward the requirements for obtaining a Juleica card.

The application should make it easy to answer two questions:

1.  **Which courses has a person attended?**
2.  **Based on those completed courses, which Juleica requirements has
    the person fulfilled, and which requirements are still missing?**

The application is a **progress and evidence tracker**. It is not
intended to replace the official Juleica application process.

------------------------------------------------------------------------

## 2. Core Domain Concept

Each course is a **unique, one-off event**.

Courses are not recurring instances of a reusable course template. The
churches plan each weekend independently, and the topics covered can be
completely different from one year or weekend to another.

Therefore:

-   `Course` represents the actual event.
-   A course has its own name, dates, location, description, and
    requirements it contributes toward.
-   There is no `Course` / `CourseOccurrence` split in the initial
    design.

For example:

``` text
Course: Youth Leadership Weekend 2026
Date: 10–11 October 2026

Covers:
- Group Leadership: 4 hours
- Legal Foundations: 2 hours
- Child Protection: 2 hours
```

A different weekend can cover a completely different combination of
requirements.

------------------------------------------------------------------------

## 3. Organizations

The application supports multiple churches or organizations cooperating
in the program.

An `Organization` can offer courses.

Users can be associated with organizations through an
`OrganizationMembership`.

This avoids assuming that a person permanently belongs to exactly one
church.

### Models

-   `Organization`
-   `OrganizationMembership`
-   `User`

------------------------------------------------------------------------

## 4. Courses

A `Course` is a single, real-world training event.

Suggested attributes:

-   `name`
-   `description`
-   `starts_at`
-   `ends_at`
-   `location`
-   `organization_id`

A course belongs to the organization offering it.

A course can cover zero or more Juleica requirements.

### Important rule

Do not create recurring-course or course-template concepts unless a
future requirement explicitly calls for them. The current domain
intentionally treats every course as a unique event.

------------------------------------------------------------------------

## 5. Course Attendance

A user participates in a course through `CourseAttendance`.

This must be a first-class model rather than a simple many-to-many
association because attendance has state.

Suggested attributes:

-   `user_id`
-   `course_id`
-   `status`

Initial attendance statuses:

-   `registered`
-   `attended`
-   `cancelled`
-   `no_show`

Only an attendance that qualifies as completed/attended should
contribute Juleica credit.

The model should enforce that a user cannot have duplicate attendance
records for the same course.

------------------------------------------------------------------------

## 6. Juleica Requirements

`JuleicaRequirement` represents an individual requirement that the
application tracks.

Requirements should be data-driven rather than hard-coded into
application logic.

Suggested attributes:

-   `name`
-   `description`
-   `required_hours`

For example:

``` text
Group Leadership
Required hours: 8

Legal Foundations
Required hours: 4

Child Protection
Required hours: 4
```

The actual requirements should be configurable so that the application
can adapt if the requirements change.

The application should not assume that every requirement has the same
number of hours.

------------------------------------------------------------------------

## 7. Course Requirements

`CourseRequirement` connects a specific course to a specific Juleica
requirement.

This is an important domain model, not merely an implementation detail.

Suggested attributes:

-   `course_id`
-   `juleica_requirement_id`
-   `hours`

Example:

``` text
Course: Youth Leadership Weekend

CourseRequirement:
  Requirement: Group Leadership
  Hours: 4

CourseRequirement:
  Requirement: Legal Foundations
  Hours: 2

CourseRequirement:
  Requirement: Child Protection
  Hours: 2
```

The same requirement can be covered by many different courses.

The same course can cover many different requirements.

This is therefore a many-to-many relationship with additional data
(`hours`).

------------------------------------------------------------------------

## 8. Accumulating Hours

Hours are accumulated across successfully completed courses.

Example:

``` text
Requirement:
Group Leadership
Required: 8 hours

Alice attends:

Course A
Group Leadership: 4 hours

Course B
Group Leadership: 4 hours

Total:
8 / 8 hours
=> Requirement fulfilled
```

If Alice only attends Course A:

``` text
4 / 8 hours
=> Requirement still incomplete
=> 4 hours remaining
```

The system should calculate this progress rather than storing a manually
maintained `completed` flag on the user/requirement relationship.

------------------------------------------------------------------------

## 9. Attendance and Qualification Credit

A course does not automatically grant credit merely because a user
registered.

Credit should only be counted for qualifying attendance.

For the initial implementation, `attended` should be the qualifying
state.

The system should calculate:

``` text
earned hours =
sum of CourseRequirement.hours
for all qualifying CourseAttendance records
for the user
for the requirement
```

Then:

``` text
remaining hours =
max(required hours - earned hours, 0)
```

A requirement is fulfilled when earned hours are greater than or equal
to required hours.

------------------------------------------------------------------------

## 10. User Progress

The application should provide a progress view for each user.

Example:

``` text
Alice

Juleica Progress

✓ Group Leadership
  8 / 8 hours

✓ Legal Foundations
  4 / 4 hours

◐ Youth Work Methods
  4 / 8 hours
  4 hours remaining

○ Child Protection
  0 / 4 hours
  4 hours remaining
```

The application should also be able to identify relevant upcoming
courses for missing requirements.

For example:

``` text
Alice is missing:

- Youth Work Methods: 4 hours
- Child Protection: 4 hours

Upcoming courses:

Youth Work Weekend
→ Youth Work Methods: 6 hours

Safeguarding Weekend
→ Child Protection: 4 hours
```

------------------------------------------------------------------------

## 11. Important Domain Distinction

The application should distinguish between:

### Attendance

A fact:

> Alice attended the Youth Leadership Weekend.

### Qualification progress

A derived result:

> Alice has accumulated 4 hours toward Group Leadership.

The application should avoid storing qualification completion as
duplicated state when it can be calculated from attendance and course
coverage.

This keeps the data consistent.

------------------------------------------------------------------------

## 12. Suggested Initial Data Model

``` text
User
  |
  +-- OrganizationMembership --> Organization
  |
  +-- CourseAttendance -------> Course
                                  |
                                  +-- CourseRequirement --> JuleicaRequirement
```

### Rails relationships

``` ruby
User
  has_many :course_attendances
  has_many :courses, through: :course_attendances
  has_many :organization_memberships
  has_many :organizations, through: :organization_memberships

Organization
  has_many :organization_memberships
  has_many :users, through: :organization_memberships
  has_many :courses

OrganizationMembership
  belongs_to :user
  belongs_to :organization

Course
  belongs_to :organization
  has_many :course_attendances
  has_many :users, through: :course_attendances
  has_many :course_requirements
  has_many :juleica_requirements, through: :course_requirements

CourseAttendance
  belongs_to :user
  belongs_to :course

CourseRequirement
  belongs_to :course
  belongs_to :juleica_requirement

JuleicaRequirement
  has_many :course_requirements
  has_many :courses, through: :course_requirements
```

------------------------------------------------------------------------

## 13. Important Database Constraints

The database should protect the important invariants.

At minimum:

-   `CourseAttendance` should be unique on `[user_id, course_id]`.
-   `CourseRequirement` should be unique on
    `[course_id, juleica_requirement_id]`.
-   Foreign keys should be used for relationships.
-   Requirement hours should be non-negative.
-   Course coverage hours should be non-negative.
-   Course start/end times should be valid.
-   Required hours should be greater than zero unless there is a
    deliberate reason to support zero-hour requirements.

------------------------------------------------------------------------

## 14. Progress Calculation

The first implementation should favor correctness and simplicity over
premature optimization.

A user requirement progress result should expose at least:

``` text
requirement
required_hours
earned_hours
remaining_hours
completed
```

Conceptually:

``` ruby
earned_hours =
  qualifying_attendances
    .joins(course: :course_requirements)
    .where(course_requirements: { juleica_requirement_id: requirement.id })
    .sum("course_requirements.hours")

remaining_hours = [
  requirement.required_hours - earned_hours,
  0
].max

completed = earned_hours >= requirement.required_hours
```

The exact query and service-object design can be decided during
implementation.

------------------------------------------------------------------------

## 15. Future Considerations

These are deliberately not required for the first version, but the
design should avoid blocking them.

### External evidence

A person might eventually receive credit from:

-   an external course
-   a First Aid certificate
-   a previous qualification
-   manually verified evidence

If this becomes necessary, introduce something like:

``` text
QualificationEvidence
  user
  requirement
  source
  hours
  achieved_at
  verified_at
```

Do not add this complexity until the product actually needs it.

### Requirement versions

If requirements differ by state, organization, or time period, a future
versioned requirement/regulation model may be needed.

The initial application should avoid hard-coding assumptions that make
such an extension impossible.

### Certificates

A future version may track certificates issued for individual courses or
the overall qualification.

------------------------------------------------------------------------

## 16. MVP Goals

The first release should allow an administrator to:

1.  Create organizations.
2.  Create users.
3.  Create Juleica requirements.
4.  Create one-off courses.
5.  Assign a course to an organization.
6.  Specify which requirements a course covers.
7.  Specify how many hours each course contributes to each requirement.
8.  Register users for courses.
9.  Record whether users attended.
10. View a user's accumulated Juleica progress.
11. See exactly which requirements and hours are still missing.
12. Find courses that can help satisfy missing requirements.

The system should make the progress calculation transparent enough that
an administrator can understand **why** a requirement is marked
complete.

------------------------------------------------------------------------

## 17. Product Principle

The most important product principle is:

> **Track evidence of training and derive qualification progress from
> it.**

Do not make the application primarily a course booking system.

The primary value is knowing:

> "What has this person completed, what does that count toward, and what
> do they still need?"
