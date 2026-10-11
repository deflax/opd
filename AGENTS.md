# Maintainer context

Small Bash/Docker wrapper for compiled oh-my-pi `omp`, pinned to v18.9.1.
`build`/`Dockerfile` own the image; `pi` owns host launch; `clearcache` deletes
only persistent `.cache` contents. Validate script syntax with `bash -n` and
the hermetic wrapper test suite with `python3 tests/run`; these mock Docker
behavior and do not replace real image builds or runtime checks.

- Preserve the primary development-toolchain baseline: apt tools, Python language
  tooling, Terraform/terraform-ls, Node 24 language tooling, global Playwright MCP,
  and managed browser/FFmpeg aliases under /ms-playwright. Preserve the exact
  `npx @playwright/mcp install-browser chromium --with-deps` method and chrome
  executable discovery; do not infer browser branding from the alias. Use the signed NodeSource repo
  and clean apt lists within installing layers. Install pinned native omp; no
  second browser installation or Bun runtime. Keep robust UID/GID/macOS mapping.
- Native browser executable lookup honors PUPPETEER_EXECUTABLE_PATH first; point
  it to /usr/local/bin/playwright-chromium. Keep PLAYWRIGHT_BROWSERS_PATH and MCP
  executable environment aligned. Native browser.headless stays true by default;
  explicit browser.open({headed:true,...}) needs working X11/XQuartz. Native
  launch defaults include --no-sandbox; do not claim browser sandbox isolation.
- config/playwright-mcp.json is preserved optional headed MCP launch config,
  mounted read-only at /config/ompd/playwright-mcp.json. Do not auto-register it,
  seed mcp.json, inject native config, or copy its sandbox/software flags into
  native browser settings. No invented browser.args. MCP remains user-managed.
- Empty OMPD_DISPLAY disables forwarding and XQuartz startup/access side effects.
  Headed macOS requires Docker Desktop networking, XQuartz network clients, and
  local connection permissions. Verify both amd64 and arm64 with actual builds;
  source/hermetic checks and prior images' success do not validate the new image.
- Resolve launcher symlinks and hash physical caller cwd for the stable native
  `/workspaces/<sanitized basename>-<12 SHA-256 hex>` session bucket.
- Persist repo `data/` as `/home/coder` by default. Never inspect runtime auth or
  sessions while developing. Do not rewrite host Git metadata or migrate sessions.
- Native profiles isolate `.omp/profiles/<name>/agent`; `default` uses
  `.omp/agent`. Trim profile names; empty/default selects default. Other names
  match `^[a-z0-9][a-z0-9._-]{0,63}$`, with no trailing dot or Windows reserved
  device names (including extensions). Reject uppercase and initial `_`/`-`.
  Last native `--profile` wins before native `--` or a registered non-launch
  command in the first residual argv position; launch/acp continue extraction.
  Bootstrap boundaries differ from resolver hoisting past leading global flags.
  Mirror pinned flag tables: strings protect their next token, except bootstrap
  `--plan` protects only value-like tokens; `--goal` protects even rejected
  flag-looking objectives. Preserve literal argv and leave validation to native.
  Reject conflicting normalized wrapper/native names. OMP_PROFILE wins whenever defined, even
  empty; PI_PROFILE is used only if OMP_PROFILE is undefined. A defined empty
  native selection means default, not OMPD_PROFILE fallback. Validate before
  seeding; normalize native environment without injecting flags.
- Seed writable config/models templates once, preserving even empty existing
  native or legacy equivalents. Never follow symlinked state directories.
  Before testing the persistent-home root with `-L`, repeatedly remove terminal
  slashes and `/.` segments, preserving `/`. Reject the final symlink before
  mkdir/seed/delete; never resolve it first or ban symlinked ancestors.
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
- Docker -i always; -t only for terminal stdin/stdout and final valid mode text/rpc-ui.
  Track last valid mode separately from sticky print and the ACP command; json/rpc/acp
  suppress TTY, but earlier machine modes do not override later text/rpc-ui.
  Restore terminal state and handle traps safely. Debug retains container metadata.
- Host networking and optional X11 weaken isolation; document implications.
- Clear only `.cache`; preserve all `.omp` auth/settings/models/sessions and
  user assets. Refuse linked cleanup roots; never guess internal cache paths.
- Rely on bundled native task-agent prompts and native model-setting schemas; do not add
  custom role files, plugins, agent-directory seeding/mounts, or parent prompts.
  Native task batching/async are enabled by default. Base task.maxConcurrency is
  4 (native default 32), overridable through normal local/profile overlays.
  Set modelRoles.default to openai/gpt-6.1-sol and task.agentModelOverrides as a
  string map: scout → openai/gpt-6-luna; reviewer/security-reviewer →
  openai/gpt-6-astra; task/sonic → openai/gpt-6.1-sol. Preserve cap4. The ollama
  profile overrides main and all five agents to ollama/gemma4:26b-16k, retaining
  local-model assignments. Local overlays can customize assignments; profiles win.
  Native --model changes main, not pinned worker mappings; request-specific worker
  models can override. A resolved model without credentials may fall back to the
  parent: local mappings are not an offline/security guarantee.
  Do not configure reasoning-effort/variant overrides. IDs are user preferences,
  not runtime-validated availability; confirm with native `./pi -- models` and
  required provider credentials/Ollama endpoint. No live delegation test is claimed.
  Reviewer is for patch/code review, not a general oracle. Delegation is not a
  rigid policy guarantee. Native task.isolation.enabled defaults false:
  children share workspace/home; require disjoint edit ownership,
  not presumed worktrees. MCP remains user-managed native persisted configuration.
- Forward unknown native arguments literally; do not invent wrapper web/port
  features. Native terminal/print/RPC/ACP stay native.
- Keep README aligned with behavior; use its official pinned upstream links.
- Verify profile/settings rules against pinned source; source checks do not
  substitute for real Docker runtime validation.
  Sources: https://github.com/can1357/oh-my-pi/blob/v18.9.1/packages/utils/src/dirs.ts
  and https://github.com/can1357/oh-my-pi/blob/v18.9.1/packages/coding-agent/src/config/settings.ts
  CLI tables: https://github.com/can1357/oh-my-pi/blob/v18.9.1/packages/coding-agent/src/cli/flag-tables.ts
  Bootstrap: https://github.com/can1357/oh-my-pi/blob/v18.9.1/packages/coding-agent/src/cli/profile-bootstrap.ts
  Dispatch: https://github.com/can1357/oh-my-pi/blob/v18.9.1/packages/coding-agent/src/cli-commands.ts
