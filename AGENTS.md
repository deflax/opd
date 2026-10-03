# Maintainer context

Small Bash/Docker wrapper for compiled oh-my-pi `omp`, pinned to v18.4.10.
`build`/`Dockerfile` own the image; `pi` owns host launch; `clearcache` deletes
only persistent `.cache` contents. Validate script syntax with `bash -n` and
the hermetic wrapper test suite with `python3 tests/run`; these mock Docker
behavior and do not replace real image builds or runtime checks.

- Resolve launcher symlinks and hash physical caller cwd for the stable native
  `/workspaces/<sanitized basename>-<12 SHA-256 hex>` session bucket.
- Persist repo `data/` as `/home/coder` by default. Never inspect runtime auth or
  sessions while developing. Do not rewrite host Git metadata or migrate sessions.
- Native profiles isolate `.omp/profiles/<name>/agent`; `default` uses
  `.omp/agent`. Trim profile names; empty/default selects default. Other names
  match `^[a-z0-9][a-z0-9._-]{0,63}$`, with no trailing dot or Windows reserved
  device names (including extensions). Reject uppercase and initial `_`/`-`.
  Last native `--profile` wins before native `--` or a registered non-launch
  subcommand boundary; launch/acp continue global extraction. Reject conflicting
  normalized wrapper/native names. OMP_PROFILE wins whenever defined, even
  empty; PI_PROFILE is used only if OMP_PROFILE is undefined. A defined empty
  native selection means default, not OMPD_PROFILE fallback. Validate before
  seeding; normalize native environment without injecting flags.
- Seed writable config/models templates once, preserving even empty existing
  native or legacy equivalents. Never follow symlinked state directories.
- Read-only `/config/ompd` repository mount; native `PI_CONFIG_FILES` order:
  base config → optional local → optional profile. Explicit native --config
  follows environment files. Pinned settings.ts splits PI_CONFIG_FILES on
  path.delimiter (colon in Linux), parses YAML mappings, and lets later overlays
  win. Native deep objects merge; arrays/scalars replace. No manual YAML
  merging or injected flags that break subcommands. Overlay values win again
  after restarting, even over user /settings edits; document this clearly.
- Keep host PI_CODING_AGENT_DIR/XDG paths out of the container. Match HOME/PATH
  to the image. Only allowlisted provider env is passed via `-e NAME`, including
  OPENAI_CODEX_OAUTH_TOKEN; never print its value.
- Never log credentials, prompt/native args, or full Docker commands. Wrapper
  diagnostics use stderr; preserve print/RPC stdout and Docker exit status.
- Docker -i always; -t only for terminal stdin/stdout, not machine mode. Restore
  terminal state and handle traps safely. Debug retains container metadata.
- Host networking and optional X11 weaken isolation; document implications.
- Clear only `.cache`; preserve all `.omp` auth/settings/models/sessions and
  user assets. Refuse linked cleanup roots; never guess internal cache paths.
- Rely on bundled native task-agent prompts and default model routing; do not add
  custom role files, plugins, agent-directory seeding/mounts, or parent prompts.
  Native task batching/async are enabled by default. Base task.maxConcurrency is
  4 (native default 32), overridable through normal local/profile overlays.
  @task inherits the active model without a usable mapping; scout/sonic use @smol
  and reviewer uses @slow. Reviewer is for patch/code review, not a general oracle.
  Delegation/model choices are not rigid policy guarantees. Native task.isolation
  defaults false: children share workspace/home; require disjoint edit ownership,
  not presumed worktrees. MCP remains user-managed native persisted configuration.
- Forward unknown native arguments literally; do not invent wrapper web/port
  features. Native terminal/print/RPC/ACP stay native.
- Keep README aligned with behavior; use its official pinned upstream links.
- Verify profile/settings rules against pinned source; source checks do not
  substitute for real Docker runtime validation.
  Sources: https://github.com/can1357/oh-my-pi/blob/v18.4.10/packages/utils/src/dirs.ts
  and https://github.com/can1357/oh-my-pi/blob/v18.4.10/packages/coding-agent/src/config/settings.ts
