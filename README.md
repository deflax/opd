# ompd — oh-my-pi in Docker

`pi` runs the pinned **oh-my-pi v18.4.10** standalone `omp` binary as `coder`
inside `ompd:latest`, using native oh-my-pi configuration and profiles.
Bun is not needed to run this binary.

## Install and run

Requires Docker, Bash, and host `sha256sum` or `shasum`; no host jq/YAML merger.

```bash
./build
./pi
mkdir -p ~/.local/bin
ln -s "$(pwd -P)/pi" ~/.local/bin/pi
# Ensure ~/.local/bin is on PATH, then run pi from your project directory.
```

The build matches host UID/GID on Linux; macOS defaults to 1000/1000 for Docker
Desktop. `OMPD_IMAGE=custom:tag ./build` changes the tag; Docker build arguments
can override defaults, e.g. `./build --build-arg OMP_VERSION=18.4.10
--build-arg USER_UID=1000 --build-arg USER_GID=1000` (on one command line). Rebuild
after image/version changes. Existing home files must be writable by the image's
coder UID; changing UID does not migrate old ownership automatically.

```bash
pi -- --help                         # native help
pi --pi-profile default              # standard ~/.omp/agent
pi --pi-profile ollama               # isolated named profile + repo overlay
pi --profile research                # native selection is preserved
pi -- --print 'Explain this project' # native noninteractive output
pi -- --resume                       # native session picker for this workspace
printf 'Explain this project\n' | pi -- --print
pi -- --mode rpc                     # native RPC; stdout stays protocol-clean
```

Unrecognized arguments pass through literally; no shell command string or eval
is used. `--` stops **wrapper** option parsing and is removed; any additional
native `--` is passed through. Wrapper options:

| Option | Behavior |
| --- | --- |
| `--pi-help` | Wrapper help without Docker |
| `--pi-profile NAME` | Selects via normalized native profile environment; injects no flags |
| `--pi-debug` | Keeps the container; prints logs/inspect/remove commands |

Profile selection follows pinned native rules: trim surrounding whitespace;
empty names and `default` select the standard agent directory, not a named
`profiles/default` directory. Other names match `^[a-z0-9][a-z0-9._-]{0,63}$`
(1–64 characters, starting with a lowercase letter or digit), must not end with
a dot, and must not be Windows reserved device names, including names with
extensions. Uppercase, initial `_`/`-`, path separators, and traversal paths are
invalid; subsequent underscores, hyphens, and dots are allowed.

Selection for **both** seeding and native execution is: last explicit native
`--profile`, explicit `--pi-profile`, defined `OMP_PROFILE`, defined
`PI_PROFILE`, wrapper default `OMPD_PROFILE`, then `default`. A defined empty
native environment selection means `default`, not a fallback to another
variable. Differing repeated native profiles are allowed; the last wins before
native `--` or a registered non-launch subcommand boundary. `launch` and `acp`
continue global profile extraction. Differing repeated wrapper selections, or
a wrapper selection that disagrees with the final native selection, are
rejected. `OMP_PROFILE` takes precedence whenever defined, even if empty;
`PI_PROFILE` is considered only when `OMP_PROFILE` is undefined. Differing environment
values are not a conflict. Explicit native arguments are not rewritten; the
launcher sets both native profile environment variables to the selected name
without injecting `--profile` or other native flags.

## Persistence and configuration

The physical current directory (`pwd -P`) is mounted read/write at stable
`/workspaces/<sanitized-basename>-<first-12-sha256-of-physical-path>`. Relative
and chained launcher symlinks resolve to the real repository; symlink aliases
of the caller's directory use the same physical workspace/hash. The repository
`data/` is the entire writable `/home/coder` (`HOME`), retaining auth (`agent.db`),
settings, profiles, and sessions associated with the canonical container cwd. Moving a
host project changes that cwd/hash, so old sessions are not automatically moved.

| Host path | Purpose |
| --- | --- |
| `config/config.yml` | One-time writable template and read-only overlay on every launch |
| `config/config.local.yml` | Optional gitignored read-only native overlay |
| `config/profiles/NAME.yml` | Optional committed native profile overlay |
| `data/.omp/agent/` | Persistent default native agent state |
| `data/.omp/profiles/NAME/agent/` | Persistent named-profile native agent state |

The base template is copied **once** into the selected agent directory's
`config.yml`, only when no `config.yml`, `config.yaml`, or legacy `settings.json`
exists. Even empty existing files are preserved. This one-time copy does not
prevent later overrides: the repository base file is also applied as an overlay
on **every launch**. Values set in the base/local/profile overlays reassert after
restart, even over changes made through native `/settings`. Change or remove the
overlay value to let a persistent setting take effect. Native config discovery
prefers `config.yml`, falling back to `config.yaml`.

The persistent home itself cannot be a symlink; symlinked ancestors are resolved
physically. Seeding refuses symlinked `.omp`, profile, or agent directory
components. Existing destination files, including dangling symlinks, suppress
seeding rather than being overwritten or followed by the seeder.

From lower to higher wrapper overlay priority:

1. Persistent native config (including the one-time template, if seeded).
2. `config/config.yml` (always).
3. `config/config.local.yml`, if present.
4. `config/profiles/NAME.yml`, if present.
5. Explicit native `--config` files, for native commands supporting that option.

The entire repository `config/` directory is mounted **read-only** at
`/config/ompd`. The container's colon-separated `PI_CONFIG_FILES` lists base,
optional local, then optional selected-profile overlay in that order.
`config/profiles/NAME.local.yml` is **not implemented** as an overlay.
The pinned settings loader splits `PI_CONFIG_FILES` on the platform path
delimiter (colon in this Linux container), parses YAML mappings, and applies
later files over earlier ones. Explicit native `--config` files are appended
after environment files. Native YAML objects deep merge; arrays and scalars
replace. Normal native project config discovery still applies; consult upstream
for the full project/environment layering contract. Host
`PI_CONFIG_FILES` is not forwarded: use the repository overlay files, or native
`--config` paths inside the mounted workspace. The wrapper does not inject
`--config` into subcommands (it is supported by default/acp/models, not every
command). Files edited while a container is running need a restart to reliably
reload.

Optional `config/models.yml`, if you create it with the **native** schema, is
also seeded once into the selected agent directory. Models seeding preserves
`models.yml`, `models.yaml`, and legacy `models.json`, including empty files.
There is no `mcp.json` seeding: configure native `mcp.json` directly in the active
persistent agent directory using the upstream schema.

### Bundled native agents

OMP v18.4.10's native task tool is enabled by default, with batching and async
execution enabled. No extra parent prompt, custom role files, or plugins are
needed; ompd adds no custom agent-directory seeding or mounts.

The base config explicitly assigns the main session and each bundled agent:

| Session/agent | Purpose | Configured model |
| --- | --- | --- |
| Main session | Interactive coding agent | `openai/gpt-6.1-sol` |
| `scout` | Read-only project exploration | `openai/gpt-6-luna` |
| `reviewer` | Patch/code review, not a general architecture oracle | `openai/gpt-6-astra` |
| `security-reviewer` | Evidence-based security review | `openai/gpt-6-astra` |
| `task` | Full-capability general worker | `openai/gpt-6.1-sol` |
| `sonic` | Mechanical updates | `openai/gpt-6.1-sol` |

These use native `modelRoles.default` and the `task.agentModelOverrides` string
map. Override assignments in `config/config.local.yml`; the selected profile
overlay takes precedence. No reasoning-effort or model-variant overrides are
configured; native thinking behavior is unchanged.
Native `--model` changes the main session, not these explicit worker assignments;
a task request can supply a worker-model override. A resolved worker model without
usable credentials may fall back to the parent model. Configured mappings are
not an offline or security guarantee.

The IDs are user-selected preferences, not runtime-validated model availability.
Confirm them with native `./pi -- models` and configure the required provider
credentials (or Ollama endpoint for the local profile). Docker/omp are unavailable
here; live delegation has not been tested.

For example, ask: “Use scout to explore this project, then task to implement the
change.” Delegation follows native prompts and model behavior, not a rigid
automatic policy guarantee.

The base config sets the shared `task.maxConcurrency` cap to **4** (native
default: 32). Override it in `config/config.local.yml` using the normal overlay
order. The lower cap may reduce throughput and concurrent cost; total cost still
depends on the workload and models used.

Native `task.isolation.enabled` defaults to `false`: children share the
mounted workspace/home. Assign disjoint edit ownership to concurrent workers;
there is no automatic worktree-isolation promise.

See [task tool usage](https://github.com/can1357/oh-my-pi/blob/v18.4.10/docs/tools/task.md)
and [task-agent discovery](https://github.com/can1357/oh-my-pi/blob/v18.4.10/docs/task-agent-discovery.md).

### Local Ollama

Ollama is a built-in discovered provider; no models template is required.
The included `ollama` overlay assigns the main session **and all five bundled
agents** to `ollama/gemma4:26b-16k`, keeping their model assignments local. The
model must exist in your Ollama instance. To change it, update the main and
per-agent assignments in `config/profiles/ollama.yml` (the profile overlay takes
precedence over `config/config.local.yml`):

```text
ollama run gemma4:26b
>>> /set parameter num_ctx 16384
>>> /save gemma4:26b-16k
>>> /bye
```

```bash
pi --pi-profile ollama
OLLAMA_BASE_URL=http://localhost:11434 pi --pi-profile ollama
```

Native discovery uses `OLLAMA_BASE_URL` / `OLLAMA_HOST`, falling back to
`localhost:11434`. Linux host networking lets the container reach host Ollama
there. Docker Desktop needs **host networking enabled** in its settings; if
required, use `OLLAMA_BASE_URL=http://host.docker.internal:11434` and configure
Ollama's listening address appropriately. This profile is not offline mode.

## Environment and credentials

| Variable | Purpose |
| --- | --- |
| `OMPD_IMAGE` | Image/tag; default `ompd:latest` |
| `OMPD_DATA_DIR` | Absolute persistent home path; created and physically resolved |
| `OMPD_PROFILE` | Wrapper default profile |
| `OMP_PROFILE`, `PI_PROFILE` | Native defaults; defined OMP_PROFILE wins, even empty (default) |
| `OMPD_DISPLAY` | Override host DISPLAY (empty explicitly disables forwarding) |
| `OMPD_NO_BANNER` | Any nonempty value suppresses launch summary |

Provider variables are forwarded **only when set**, via Docker `-e NAME`, never
by printing their values:

```text
OPENAI_API_KEY OPENAI_CODEX_OAUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_OAUTH_TOKEN
GEMINI_API_KEY GOOGLE_API_KEY OPENROUTER_API_KEY GROQ_API_KEY
MISTRAL_API_KEY XAI_API_KEY DEEPSEEK_API_KEY OLLAMA_API_KEY
OLLAMA_HOST OLLAMA_BASE_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN AWS_REGION AWS_DEFAULT_REGION AWS_PROFILE
```

Prefer a secret manager/exported environment or native persisted login. Host AWS
credential files are **not** automatically mounted; `AWS_PROFILE` alone does not
make host profiles available. No arbitrary host environment or host home is
forwarded. Home data and local overlays can contain secrets; do not commit them.
Docker admins and processes with access to container configuration can still
inspect container environment secrets.

## Maintenance and debugging

```bash
./clearcache --dry-run
./clearcache
pi --pi-debug
# Use the printed docker logs / docker inspect / docker rm commands.
```

Stop containers before cleanup. Only contents of home `.cache/` are removed;
npm's `.npm/` is untouched. All `.omp/` data, including databases, profiles,
auth, settings, models, and sessions, is preserved. A symlinked persistent home
or `.cache` root is refused with an error; ancestors of the home path are
physically resolved. Direct and nested symlinks **inside** `.cache` are unlinked,
never followed to their targets. `OMPD_DATA_DIR` applies to cleanup too. No
guessed `.omp/cache` or broad home/node_modules deletion is performed.
Back up `data/` separately.

The launcher verifies Docker and the image before seeding state and reports
build guidance on failure. It returns Docker's exit status. All launch/debug
messages go to **stderr**, leaving native stdout usable for print/JSON/RPC.
Docker always receives `-i`; `-t` is added only when stdin and stdout are actual
terminals and print/RPC/JSON/ACP mode is not selected. Terminal state restoration is
TTY-only; INT/TERM/HUP terminate the wrapper with conventional signal statuses.

## Networking, X11, and security limits

Docker runs with `--init`, `--network host`, `--shm-size=1g`, cleared entrypoint,
`--user coder`, `no-new-privileges:true`, all capabilities dropped except
CHOWN/SETUID/SETGID. The image's UID/GID are configured at build time. This limits
privileges but is **not** a complete sandbox: tools can modify the mounted
workspace/home and access host-network services. Docker Desktop host networking
is opt-in; behavior differs from native Linux. Do not expose untrusted services.

On Linux, when DISPLAY is nonempty, existing `/tmp/.X11-unix` sockets and an
explicit existing `XAUTHORITY` file are mounted read-only. XWayland may work;
Wayland sockets/GPU devices are not mounted. On macOS the launcher best-effort
starts installed XQuartz and grants `localhost`/`127.0.0.1` access with `xhost`;
local/launchd display values become `host.docker.internal:0` unless
`OMPD_DISPLAY` is explicitly set. Enable XQuartz network-client connections if
needed. X11 grants desktop access and can weaken isolation; disable it with
`OMPD_DISPLAY=''`. Docker mount paths containing commas are rejected rather
than misinterpreted. No Docker socket is mounted.

## Verification

From the repository directory, local checks need no Docker daemon:

```bash
bash -n pi build clearcache
python3 tests/run
```

The Python checks use a mock Docker argv/environment recorder and temporary
repository copies, not a real image or upstream runtime. They do not establish
that the image builds or native configuration loads correctly.
No real Docker build or smoke-test result is claimed here.

For a **real Docker smoke test**, run the following on a Docker-enabled host
with host networking available (opt-in on Docker Desktop). These are suggested
checks, not a claim that a real build or launch has been tested:

```bash
./build
# If running as root, supply positive non-root IDs instead:
# ./build --build-arg USER_UID=1000 --build-arg USER_GID=1000
smoke_home="$(mktemp -d)" # Must be writable by the image's coder UID.
OMP_PROFILE=default OMPD_DATA_DIR="$smoke_home" OMPD_DISPLAY='' ./pi -- --version
OMP_PROFILE=default OMPD_DATA_DIR="$smoke_home" OMPD_DISPLAY='' ./pi -- --help
OMPD_DATA_DIR="$smoke_home" OMPD_DISPLAY='' ./pi --pi-profile smoke -- --help
test -f "$smoke_home/.omp/agent/config.yml"
test -f "$smoke_home/.omp/profiles/smoke/agent/config.yml"
```

Confirm the reported version is 18.4.10 for the default build, commands exit
successfully, and named/default state stays separate. With a configured provider,
also try native `--print` and an interactive launch; verify overlay values return
after restart even after `/settings` edits. Use `--pi-debug` if container
inspection is needed. Stop/remove retained debug containers before deleting the
temporary home. Do not use real auth/session data for these checks.

## Sources

- [oh-my-pi source and native documentation](https://github.com/can1357/oh-my-pi)
- [Pinned v18.4.10 source](https://github.com/can1357/oh-my-pi/tree/v18.4.10)
- [Native coding-agent docs](https://github.com/can1357/oh-my-pi/tree/v18.4.10/docs)
- [Pinned settings loader (`settings.ts`)](https://github.com/can1357/oh-my-pi/blob/v18.4.10/packages/coding-agent/src/config/settings.ts)
- [Pinned profile/directory rules (`dirs.ts`)](https://github.com/can1357/oh-my-pi/blob/v18.4.10/packages/utils/src/dirs.ts)
- [Native task tool](https://github.com/can1357/oh-my-pi/blob/v18.4.10/docs/tools/task.md)
- [Native task-agent discovery](https://github.com/can1357/oh-my-pi/blob/v18.4.10/docs/task-agent-discovery.md)
- [Ollama documentation](https://docs.ollama.com/)
