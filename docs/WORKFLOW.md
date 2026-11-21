# Day-to-day development commands

For installation and first-time pairing, see [ONBOARDING.md](ONBOARDING.md).
T3's Git controls can perform the same branch, commit, pull, and push operations
as the commands below.

## Where to run commands

- **Host terminal:** your project directory on Linux/macOS, or the checkout in
  Ubuntu/WSL on Windows. Docker Desktop must be running where applicable.
- **Container terminal:** a T3 terminal in the **container environment**, at
  `/app`. Run all Ruby/Rails and day-to-day Git commands here.
- One checkout means one active feature branch. Stop editing agents, tests, and
  Rails before switching branches; host and container share the same files.

## Start your day

**Host terminal:**

```sh
devcontainer up --workspace-folder .
```

Open host T3, select the saved container environment, and open `/app`.
If you need to pair a new device or renew access:

```sh
devcontainer exec --workspace-folder . t3 pair
```

Use **Settings → Environments → Add environment** with
`http://127.0.0.1:13773` and the fresh pairing code. Do not share the code or use
the container IP. Use your configured host port if you changed the default.

## Start and stop Rails

**Container terminal:**

```sh
bin/dev
```

This runs Rails and the Tailwind watcher. Open
<http://localhost:3005/auth/sign_in> on the host, or use your configured
`RAILS_HOST_PORT`. Keep this terminal open; use another terminal for commands.
Press **Ctrl+C** in this terminal to stop Rails and the watcher.

## Begin a feature

**Container terminal:** first inspect your checkout:

```sh
git status
git branch --show-current
git remote -v
```

If you have unfinished changes, commit them or deliberately save them before
switching. Do not discard them just to make a branch switch work.

For this repository's `master` base branch, assuming your remote is `origin`:

```sh
git switch master
git pull --ff-only origin master
git switch -c feature/short-description
```

Replace the feature name. If your repository uses a different base branch or
remote, substitute it. `--ff-only` stops rather than creating an unexpected merge
if local and remote history have diverged; ask for help if it fails.

After switching to an existing branch, or when gems/migrations changed:

```sh
bundle install
bin/rails db:prepare
bin/rails db:test:prepare
```

Restart Rails afterwards. Ruby, system-library, or devcontainer configuration
changes may require a container rebuild instead; see below.

**Database changes do not switch with Git branches.** If a branch applied
migrations, switching away leaves those changes in PostgreSQL. Agree on a
rollback or disposable-development-database recovery plan before switching
between incompatible schemas. Do not routinely reset or drop databases.

## Run checks

**Container terminal:** run these in order before finishing a feature:

```sh
bin/rails db:test:prepare
bundle exec rspec
bundle exec rubocop
bundle exec i18n-tasks health
bundle exec i18n-tasks check-normalized
```

Prepare the test database **before**, not concurrently with, RSpec. Do not point
`TEST_DATABASE_URL` at the development database. Avoid running simultaneous test
runs against the same test database.

For a specific spec or example (replace the path/line as needed):

```sh
bundle exec rspec spec/requests/user_progress_spec.rb
bundle exec rspec spec/requests/user_progress_spec.rb:25
```

For devcontainer launcher changes, also run:

```sh
bash .devcontainer/test.sh
```

## Useful Rails commands

**Container terminal:**

| Command | Purpose |
| --- | --- |
| `bin/rails console` | Open a Ruby console; use `exit` to leave |
| `bin/rails routes` | List application routes |
| `bin/rails db:migrate:status` | Show applied and pending migrations |
| `bin/rails db:migrate` | Apply development migrations; prepare the test DB afterwards |
| `tail -n 100 -f log/development.log` | Follow Rails development logs; Ctrl+C to stop |

The Rails console can change real development data. Use `bin/rails db:seed` only
when you intentionally want to load/update the demo dataset, not every morning.

## Review, commit, and push

**Container terminal:**

```sh
git status
git diff
git diff --check
```

Stage only the intended files, inspect what will be committed, then commit:

```sh
git add path/to/changed-file path/to/another-file
git diff --cached
git commit -m "Describe the change"
git push -u origin HEAD
```

Replace the example paths/message. `git diff` does not show untracked file
contents, so inspect new files listed by `git status` too. Never commit tokens,
pairing codes, `.env` secrets, or Rails keys.

For GitHub, open a pull request using T3 or interactively:

```sh
gh pr create
```

After review and merge, start the next feature from an updated `master`, not from
the previous feature branch. Do not force-push or resolve unfamiliar divergence
by resetting/discarding work without agreement.

## Authentication troubleshooting

**Container terminal:**

```sh
gh auth status
git remote -v
```

For the recommended GitHub HTTPS setup, authenticate if necessary and configure
Git's credential helper:

```sh
gh auth login
gh auth setup-git
git fetch origin
```

Choose HTTPS and ensure the remote uses HTTPS. Host clone authentication and
container authentication are separate. Do not paste credentials into a remote
URL or publish authentication output containing secrets.

## Stop for the day

Finish/save work and stop editing agents. Stop Rails with **Ctrl+C**, then run
in the **host terminal**:

```sh
docker compose -f .devcontainer/compose.yml stop
```

This disconnects container T3 but preserves checkout files, database data, agent
history, and authentication volumes. Closing the host T3 window alone is not a
container shutdown. Start next time with `devcontainer up --workspace-folder .`.

## Inspect container problems

**Host terminal:**

```sh
docker compose -f .devcontainer/compose.yml ps -a
docker compose -f .devcontainer/compose.yml logs --tail 100 jg-lead
docker compose -f .devcontainer/compose.yml logs --tail 100 postgres
```

Read logs locally; redact pairing links/codes and credentials before sharing.
If Rails preparation failed after the problem has been fixed, retry:

```sh
devcontainer exec --workspace-folder . bash .devcontainer/container.sh prepare
```

You can also run an individual container command from the host:

```sh
devcontainer exec --workspace-folder . bundle exec rspec
```

## Rebuild after infrastructure changes

Stop active agents and Rails first. In the **host terminal**:

```sh
devcontainer up --workspace-folder . --build-no-cache --remove-existing-container
```

This is slower than normal startup and disconnects T3 sessions. Named volumes
and the checkout survive, but ad-hoc OS packages and other unmounted container
files do not. Reconnect to the saved environment when startup completes.

**Never use `down -v`, `docker volume prune`, or `docker system prune --volumes`
as routine cleanup.** They can delete databases, history, and authentication.
Do not rename the Compose project or volumes casually. See onboarding for
backups, version pins, platform limitations, and recovery details.
