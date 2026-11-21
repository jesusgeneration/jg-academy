# Development with T3 Code and the devcontainer

Already set up? See [WORKFLOW.md](WORKFLOW.md) for daily startup, Git, Rails,
testing, shutdown, and troubleshooting commands.

## TL;DR — Windows 11 setup and connection

Install **Docker Desktop and T3 on Windows**. Install **Git, Node.js, and the
Dev Container CLI inside WSL/Ubuntu**. No VS Code or host Ruby is needed.
Windows/WSL onboarding still needs a full end-to-end manual verification.

1. **Install WSL2 with Ubuntu.** Open PowerShell as Administrator:

   ```powershell
   wsl --install -d Ubuntu
   ```

   Restart if prompted, open Ubuntu, and finish creating your Linux user.
   Check `wsl --list --verbose` in PowerShell; Ubuntu should show version `2`.

2. **Install [Docker Desktop for Windows](https://docs.docker.com/desktop/setup/install/windows-install/).**
   Start it, select **Settings → General → Use the WSL 2 based engine**, and enable
   Ubuntu under **Settings → Resources → WSL Integration**. Use Linux containers.
   Leave Docker Desktop running. Do not install a second Docker daemon in Ubuntu.

3. **Install Git in Ubuntu.** Run the rest of the shell commands in the Ubuntu
   terminal, not PowerShell:

   ```sh
   sudo apt update
   sudo apt install -y git curl build-essential python3
   git --version
   docker version
   docker compose version
   ```

   `docker version` should show both a client and a reachable server. If it does
   not, check that Docker Desktop is running and Ubuntu integration is enabled.

4. **Install Node.js LTS and npm in Ubuntu.** Follow the Linux/nvm instructions
   on the [Node.js download page](https://nodejs.org/en/download), then open a new
   Ubuntu terminal if needed and run:

   ```sh
   nvm install --lts
   nvm alias default 'lts/*'
   node --version
   npm --version
   ```

   npm comes with Node; Windows 11 does not include either by default. Installing
   Node on Windows alone is not enough for these Ubuntu commands.

5. **Install the Dev Container CLI in Ubuntu:**

   ```sh
   npm install -g @devcontainers/cli
   devcontainer --version
   ```

6. **Install the [T3 Code desktop app on Windows](https://github.com/pingdotgg/t3code/releases).**
   Use a desktop release compatible with the container's pinned T3 version
   (currently 0.1.11). You do not need to install T3 or OpenCode manually inside
   Ubuntu; container startup installs their container versions.

7. **Clone and start the project from Ubuntu.** Replace `REPOSITORY_HTTPS_URL`
   with the team's repository URL; ensure your Git account has access first.
   Keep the checkout under your Linux home, not `/mnt/c`:

   ```sh
   mkdir -p ~/projects
   cd ~/projects
   git clone REPOSITORY_HTTPS_URL jg-lead
   cd jg-lead
   devcontainer up --workspace-folder .
   ```

   Initial startup builds the environment, installs dependencies, prepares the
   databases, and starts T3. Private-repository authentication for this initial
   host clone is separate from the later container Git login.

8. **Pair Windows T3 with the container.** In the same Ubuntu terminal:

   ```sh
   devcontainer exec --workspace-folder . t3 pair
   ```

   In Windows T3, open **Settings → Environments → Add environment**. Enter
   **`http://127.0.0.1:13773`** and the fresh pairing code. Use this localhost
   address, not a container IP printed by the CLI. Keep pairing codes private.
   Add **`/app`** as a project in the **container environment**.

9. **Connect OpenCode and Git.** In T3's **Settings → Providers**, select the
   container environment, enable OpenCode, leave **Server URL** empty, and
   complete provider sign-in. Open a T3 terminal in that environment at `/app`:

   ```sh
   git config --local user.name "Your Name"
   git config --local user.email "you@example.com"
   gh auth login
   gh auth setup-git
   ```

   For GitHub, choose HTTPS and ensure the repository remote uses HTTPS.
   This login enables container-side pulls/pushes; T3/OpenCode login alone does
   not authenticate Git.

10. **Start Rails in the container's T3 terminal:**

    ```sh
    bin/dev
    ```

    Open **http://localhost:3005/auth/sign_in** on Windows. Run quality checks in
    another container terminal using the commands below. On subsequent days,
    start Docker Desktop, run `devcontainer up --workspace-folder .` from the
    checkout in Ubuntu, and select the saved container environment in T3.

For macOS/Linux, install Git, Node.js LTS, the Dev Container CLI, and T3 directly
on your host. Use Docker Desktop on macOS or Docker Engine with Compose on Linux;
skip WSL and follow the same clone, startup, and pairing steps.

## Setup overview

Use the existing development container as a local **remote environment** for
the T3 desktop app. T3's server and OpenCode run inside the container, alongside
Ruby and Rails. PostgreSQL remains a separate Compose service. The host runs
Docker, the Dev Container CLI, Git, and the T3 desktop app; it needs no Ruby,
PostgreSQL installation, or VS Code.

```text
Host computer
  T3 desktop app
       | paired connection through a localhost-only published port
       v
  Development container
    T3 server (t3 serve --lan)
    OpenCode, Git, Ruby, Rails, RSpec, RuboCop
    /app (the host's mounted project checkout)
       |
       v
  PostgreSQL container and persistent development data
```

Use ordinary Git branches and work on one feature at a time. There are no
worktrees, SSH server, or additional T3-only container. Keep the existing VS Code
devcontainer workflow working and do not change the production Docker image.

The configuration starts T3 automatically as `vscode`, publishing container port
3773 on **host `127.0.0.1:13773` only** (avoiding desktop T3's usual port).
Rails is started explicitly and published
on `127.0.0.1:3005`. PostgreSQL is private to the Compose network. No host Ruby,
SSH daemon, cloud/T3 Connect, systemd, or additional T3 container is needed.

The pinned defaults are **T3 0.1.11** and **OpenCode 2.0.18**. T3 0.1.11 documents
support for OpenCode 2.0.18 and newer. Its standalone installer supports Linux
x86_64 and ARM64, including Linux containers on macOS/Windows. Native Intel Mac
T3 CLI binaries are not available, but this workflow runs the Linux CLI in Docker.
Use a matching T3 desktop release. See verification status below for tested scope.

## Install on your computer

- **Git** and access to this repository.
- **Docker Engine with Compose** on Linux, or **Docker Desktop** using Linux
  containers on macOS/Windows.
- **Node.js LTS**, which includes npm, for the Dev Container CLI. Windows 11
  does not include Node.js or npm by default.
- **T3 Code desktop app**.
- **Dev Container CLI**:

  ```sh
  npm install -g @devcontainers/cli
  devcontainer --version
  ```

The CLI may need additional native build prerequisites; consult its installation
guide if npm reports a build error. Node/npm support the host-side CLI; the Rails
application itself has no Node build step.

### Windows

The recommended command environment is WSL2, with Docker Desktop integration
enabled for that distribution. Install Git, Node/npm, and the Dev Container CLI
inside WSL, and clone the repository into its Linux filesystem, not `/mnt/c`.
Run the setup commands there, while using the Windows T3 desktop app as the
client. Verify that the container's published localhost port is reachable from
Windows. A Windows Node installation does not replace a WSL Node installation.

Native Windows CLI execution is an alternative that must be tested separately;
do not mix Windows and WSL Git executables or checkout paths.

## Start the environment

Start Docker, clone the repository, and open a terminal in its root directory.
Use the Dev Container CLI rather than plain `docker compose up`: the CLI also
processes devcontainer features and lifecycle commands.

```sh
devcontainer up --workspace-folder .
```

The first start builds the image/features, downloads the pinned CLIs, runs
`bundle install` if needed, and prepares the development and test databases.
`db:prepare` can seed a new development database; it does not reset an existing
one. Startup waits for PostgreSQL readiness and then for T3's HTTP listener.
Internet access is required for uncached images, features, gems, and tools.

The container command installs missing/mismatched CLIs idempotently and then
`exec`s `t3 serve --lan --host 0.0.0.0 --port 3773 /app`. Docker's init forwards
signals/reaps children; T3 writes to Docker logs. There is no background-service
installer or restart loop hiding installation failures. `postCreateCommand`
prepares Rails and `postStartCommand` checks T3 readiness. The Dev Container CLI
honors both. Plain Compose does not install the features or run those hooks.

`--lan` allows the container interface, not the host LAN. Never change the host
binding to `0.0.0.0` or enable T3 Connect for this local-only workflow. Other
containers on this Compose network can reach T3; pairing is still required.

If ports are taken, export alternative **host** ports before every up/recreation:

```sh
export T3_HOST_PORT=23773
export RAILS_HOST_PORT=13005
devcontainer up --workspace-folder . --remove-existing-container
```

Container ports remain 3773 and 3005. Defaults require no `.env` file. Existing
ignored `.env` files are not the database configuration source; audit any legacy
file for overrides before running Foreman (`bin/dev` loads `.env`).
Recreation is necessary to change published ports on an existing container and
disconnects its running agents/terminals; stop their work first.

VS Code's **Reopen in Container** uses this same setup and keeps its extensions
and port forwarding. Avoid switching branches or starting two servers against
the same checkout from two editors at once.

## Connect the host T3 app

1. Generate a pairing link in the container:

   ```sh
   devcontainer exec --workspace-folder . t3 pair
   ```

2. In the host T3 desktop app, use **Settings → Environments → Add environment**.
   Use `http://127.0.0.1:13773` (or your `T3_HOST_PORT`) as the server address and
   the fresh code from step 1. The CLI may print container IP addresses: those
   are **not** the host endpoint. If pasting a full pairing URL, replace only its
   embedded server URL/address (which may be URL-encoded) with the localhost
   endpoint, preserving its pairing code and the link's other fields.
   There is no `t3 pair --host`/`--url` override in the pinned CLI.
3. Add `/app` as a project **in the container environment**, not the host
   environment.
4. Enable OpenCode in **Settings → Providers** for the container environment.
   Leave **Server URL** empty; T3 launches the local provider. Authenticate there,
   or run `opencode auth login` interactively in a container terminal, then
   refresh provider status. If discovery fails, use the binary path
   `/home/vscode/.opencode/bin/opencode`.

Treat pairing links, provider credentials, and persisted authentication volumes
as secrets. Do not commit or share them, including screenshots and Docker logs
that can include startup pairing details. Codes expire; generate another with
`t3 pair` rather than restarting. Revoke devices in **Sharing & access** for the
container environment. The host's T3 data and provider sign-ins are not mounted.

You can disable T3 desktop's **Local environment** if you only want to run agents
in this container; that does not delete host projects/history.

## Git identity and repository access

T3's Git controls and agent Git commands operate inside the container. Because
`/app` is the mounted checkout, commits and branch switches are also visible on
the host. Do not operate on different branches from host and container at once.

Set your identity in a container terminal at `/app`:

```sh
git config --local user.name "Your Name"
git config --local user.email "you@example.com"
```

For a GitHub repository, the recommended initial authentication method is HTTPS
with GitHub CLI inside the container:

```sh
gh auth login
gh auth setup-git
```

Select HTTPS during login and ensure the repository's remote uses an HTTPS URL.
The dedicated GitHub config volume preserves login; the Git config volume
preserves `gh auth setup-git`. On this headless image, `gh` may store credentials
in its config file rather than a system keyring. Volumes are private to the
container user (directory mode 0700), but are **not encrypted**: host admins and
Docker access can read them. Use disk encryption and protect backups.
T3/OpenCode sign-in does not sign Git into GitHub. No host secrets are copied or
baked into the image. `git fetch` can verify read access; do not push just to
test authentication. Interactive login is always your action.

### File permissions

The Dev Container CLI adjusts `vscode`'s UID/GID for the local Linux user.
Clone/own the checkout as that user, not root. Startup repairs ownership only
inside the six dedicated agent/auth volume directories, never recursively on
`/app` or the entire home. Docker Desktop handles bind permissions differently;
check that a container-created file remains editable on the host. If Git reports
dubious ownership, fix the specific ownership/mount problem; do not use
`safe.directory=*` or broad `sudo chown -R` as a workaround.

## Run Rails and quality checks

In a T3 terminal for the container environment, run commands directly from
`/app`—there is no host Ruby installation and no need for nested Docker commands.
Dependencies and databases are prepared on container creation:

```sh
bin/rails db:seed            # optional: refresh demo data, not a routine startup
bin/dev
```

Rails binds `0.0.0.0:3005` **inside** the container so Docker can reach it. Open
`http://127.0.0.1:3005` on the host (use `RAILS_HOST_PORT` if changed), or use T3's
**Servers → Forward** / **Forwarded ports** command for container port 3005.
T3 can select another local forwarding port if the published one is occupied.
VS Code's `forwardPorts` setting alone is not Docker port publishing.
See the root README for demo accounts. For initial local work use seeded password
login; Google OAuth needs an exact registered callback URL for the chosen port.

Before finishing a feature, run:

```sh
bin/rails db:test:prepare
bundle exec rspec
bundle exec rubocop
bundle exec i18n-tasks health
bundle exec i18n-tasks check-normalized
bash .devcontainer/test.sh  # fast launcher tests; no downloads or credentials
```

From a host terminal, prefix commands with, for example:

```sh
devcontainer exec --workspace-folder . bundle exec rspec
```

Compose explicitly supplies `DATABASE_URL` ending in `jg_lead_development` and
`TEST_DATABASE_URL` ending in `jg_lead_test`. `config/database.yml` uses the test
URL in test mode even when `DATABASE_URL` names development. Do not unset the
test URL or replace it with a development/production URL. Without this container,
connection-only URLs (no database path, as in CI) retain the separate YAML names.
The `postgres` hostname is internal to Compose; no host PostgreSQL is needed.

## Daily workflow

1. Start Docker and the devcontainer, then select its environment in T3.
2. Pull the intended base branch and create/select your feature branch.
3. Work on one feature, run the checks, and review the changes.
4. Commit and push through T3; open a pull request as appropriate.
5. Finish or deliberately save unfinished changes and stop active agent edits,
   tests, and Rails before switching branches. Never silently discard work.
6. After switching, reinstall changed gem dependencies, prepare the database,
   and restart Rails. Rebuild the container when Ruby/system dependencies change.

**Git branches do not isolate the database.** A migration applied on one branch
remains after switching to another. For schema-changing work, decide whether to
roll back while still on the original branch or explicitly rebuild the disposable
development database. Resetting data requires confirmation; routine startup and
branch switching must never delete data automatically.

Stopping containers must preserve database and agent-state volumes. Recreating a
container disconnects running agents. Removing volumes deletes persistent data;
do not use broad Docker cleanup commands as normal shutdown instructions.

### Stop, restart, rebuild, and update

After stopping active agents and Rails, shut down without removing data:

```sh
docker compose -f .devcontainer/compose.yml stop
```

Start again with `devcontainer up --workspace-folder .` so lifecycle hooks run.
For image/feature changes, recreate through the Dev Container CLI:

```sh
devcontainer up --workspace-folder . --build-no-cache --remove-existing-container
```

This disconnects sessions and removes the container's writable layer, not named
volumes or the mounted checkout. Do not use `down -v`, `volume prune`, or
`system prune --volumes`. The Compose project remains `jg-lead`; existing
`jg-lead_postgres-data-jg-lead` and `jg-lead_opencode-data-jg-lead` volumes are
reused. Do not rename the project/volumes or change PostgreSQL's major version
without an explicit backup/migration plan. Old differently named volumes from
other setups are not auto-migrated or removed.

| Persisted path in `/home/vscode` | Purpose |
| --- | --- |
| `.t3` | Separate container T3 home, runtime, pairing, history, settings/browser |
| `.opencode` | OpenCode installer/binary |
| `.local/share/opencode` | Existing OpenCode data, database, authentication, logs |
| `.config/opencode` | OpenCode user/service configuration |
| `.config/gh` | GitHub CLI authentication |
| `.config/git` | Git global configuration and credential helper |

Other home files and OS packages do not persist across recreation. OpenCode's
`.local/state/opencode` runtime service registration is intentionally ephemeral;
its data/config persist and T3 starts its provider when needed. Back up dedicated
volumes while the containers are stopped, and treat backups as secrets. No Docker
socket or host home/auth directories are mounted in the development container.

Change version defaults in Compose deliberately, or export `T3CODE_VERSION` and
`OPENCODE_VERSION` before recreation to select compatible exact versions. Keep
those exports for subsequent recreations. The installer reconciles versions on
each start, so `t3 update` or provider self-update alone is not a persistent pin
change. Back up state before upgrades: OpenCode 2 migrates 1.x databases; never
run 1.x and 2.x against the same data. Old T3 releases without standalone archives
are not supported by this launcher.

### Recovery and optional browser support

```sh
docker compose -f .devcontainer/compose.yml ps -a
docker compose -f .devcontainer/compose.yml logs --tail 100 jg-lead
```

Read logs locally and redact pairing codes, URLs, and credentials before sharing.
An install failure stops the container; fix connectivity/version/volume access
and rerun `devcontainer up`. A lifecycle preparation failure is reported by the
CLI even if T3 is listening; fix it and rerun
`devcontainer exec --workspace-folder . bash .devcontainer/container.sh prepare`.
For missing gems after a branch change run `bundle install`; prepare both
databases after migrations. Startup does not reset database or agent state.

T3 browser tooling is optional. Minimal Linux images may need libraries, fonts,
or a host-compatible Chrome sandbox. Follow the exact diagnostic T3 prints;
its documented helper is `sudo t3 browser setup` (or use the absolute T3 binary
path if sudo strips PATH). Packages installed interactively need reinstalling
after a rebuild. This setup does **not** disable Chrome's sandbox or add privileged
Docker flags. Some host/container sandbox combinations need separate testing.

## Verification status

Verified on **2026-11-21, Linux x86_64**, with Docker 29.9.2, Compose 5.6.1,
Dev Container CLI 0.91.0, and Node 26.13.1:

- Feature/image build and complete `devcontainer up --remove-existing-container`
  lifecycle, including gem installation and development/test DB preparation.
- Non-root foreground T3 0.1.11, OpenCode 2.0.18, Ruby 4.0.5, and Git/GitHub CLI
  discovery from a non-interactive container process.
- Host HTTP 200 for T3 on `127.0.0.1:13773` and Rails' sign-in page on
  `127.0.0.1:3005`; inspected localhost-only bindings and no PostgreSQL publication.
- Separate resolved development/test databases; host-writable container-created
  checkout file with the expected UID/GID; private state-directory permissions.
- Stop/restart via the CLI and recreation preserving all six state volumes;
  unchanged CLI file timestamps demonstrated reuse rather than reinstallation.
  T3 stopped without forced kill (its reported interrupt exit code was 130).
- `bin/rails db:test:prepare`, full RSpec (**386 examples, 0 failures**), RuboCop
  (**109 files, no offenses**), i18n health and normalization, launcher regression
  tests, Bash syntax, ShellCheck, Compose config/binding assertions, and
  `git diff --check`. Run database preparation **before**, not alongside, RSpec.

Interactive T3 desktop pairing, provider/GitHub login, authenticated push, VS Code
UI, optional Chrome tooling, macOS/ARM64, and Windows/WSL2 require user/manual
platform verification; do not assume they have been tested merely because the
configuration supports them.

## References

- [T3 remote access and pairing](https://github.com/pingdotgg/t3code/blob/main/docs/user/remote-access.md)
- [T3 installation and providers](https://github.com/pingdotgg/t3code/blob/main/docs/user/install.md)
- [Pinned T3 release's OpenCode compatibility](https://github.com/pingdotgg/t3code/blob/v0.1.11/docs/user/providers-opencode.md)
- [OpenCode config and persistent paths](https://opencode.ai/docs/troubleshooting)
- [Dev Container CLI](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli)
- [Project overview and demo accounts](../README.md)
