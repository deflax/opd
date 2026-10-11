# ompd

Docker wrapper for native `omp`, pinned to **v18.9.1**.

Official upstream: [release](https://github.com/can1357/oh-my-pi/releases/tag/v18.9.1),
[source](https://github.com/can1357/oh-my-pi/tree/v18.9.1), and
[pinned installer](https://github.com/can1357/oh-my-pi/blob/v18.9.1/scripts/install.sh).

`./build` creates the image. `./pi` runs `omp` inside it with the current
project mounted under `/workspaces/...` and persistent state in `data/`.

## Quick start

On each machine, clone this repository, then:

```bash
./build
./pi -- login   # Configure provider authentication through native omp.
./pi

# Optional: install the launcher on PATH.
mkdir -p ~/.local/bin
ln -s "$(pwd -P)/pi" ~/.local/bin/pi
```

The repository supplies initial settings, not credentials. Each clone keeps its
own provider authentication and subsequent settings in its persistent `data/`
home. Do not commit or copy that home as part of the configuration template.

Common calls:

```bash
pi -- --help
pi -- --print 'Explain this project'
pi -- --mode rpc
pi --pi-profile work
pi --profile work
printf 'Explain this project\n' | pi -- --print
```

`--` stops wrapper parsing. Everything after it is passed to native `omp`.
Unknown arguments are forwarded literally; the wrapper does not use `eval`.

The launcher mirrors native argument boundaries to select persistent profile
state and terminal allocation. Native `omp` owns execution, authentication, and
ongoing settings; the wrapper keeps native arguments intact.

Docker keeps stdin attached (`-i`). A TTY (`-t`) is allocated only when both
stdin and stdout are terminals and the final valid native mode is `text` (the default)
or `rpc-ui`. The last valid `--mode` wins: an earlier `json`, `rpc`, or `acp` mode does
not permanently disable a later `text` or `rpc-ui` mode. `--print`/`-p` and the
`acp` command always suppress the TTY, even with a later `--mode text`. Tokens
used as option values or passed after native `--` do not select a mode.

Wrapper options:

| Option | Behavior |
| --- | --- |
| `--pi-help` | Show wrapper help without Docker |
| `--pi-profile NAME` | Select native profile state and its first-launch config seed |
| `--pi-debug` | Keep the container and print inspect/log/remove hints |

## Build

Requirements: Docker, Bash, and `sha256sum` or `shasum`.

```bash
./build
./build --no-cache                       # Reinstall omp without rebuilding Debian/tools
./build --base                          # Rebuild the Debian/toolchain image only
./build                                 # Build omp on the updated base
OMPD_IMAGE=my-ompd ./build
./build --build-arg USER_UID=1000 --build-arg USER_GID=1000
```

Linux builds use the host UID/GID by default. macOS builds use `1000:1000`
because Docker Desktop does not need the host account IDs inside the image.
Existing files under `data/` must be writable by the image user.

The image is built from two separate Dockerfiles:

- `Dockerfile.base` builds `ompd-base:latest` from Debian, including the development
  tools, Node, Playwright MCP, and managed Chromium/FFmpeg.
- `Dockerfile` builds `ompd:latest` from that base, installing native omp and
  creating the UID/GID-mapped runtime user.

`./build` creates the base automatically if its tag is absent locally; otherwise
it reuses it without rebuilding it. Changes to `Dockerfile.base` or
`playwright-chromium-launcher` require an explicit `./build --base`, followed by
`./build`. To refresh all base dependencies, use `./build --base --pull --no-cache`.
Changing omp's version or runtime UID/GID does not rebuild the toolchain.

Set `OMPD_BASE_IMAGE` to select a different base tag for both build commands.
Docker options apply only to the selected build; the automatic missing-base build
uses defaults. For cross-architecture builds, build a matching base explicitly
first and use separate tags for each architecture:

```bash
OMPD_BASE_IMAGE=ompd-base:amd64 ./build --base --platform linux/amd64
OMPD_BASE_IMAGE=ompd-base:amd64 OMPD_IMAGE=ompd:amd64 ./build --platform linux/amd64
OMPD_BASE_IMAGE=ompd-base:arm64 ./build --base --platform linux/arm64
OMPD_BASE_IMAGE=ompd-base:arm64 OMPD_IMAGE=ompd:arm64 ./build --platform linux/arm64
```

Direct Docker builds must also build or pull the base first, then select it with
`docker build --build-arg BASE_IMAGE=...` when not using `ompd-base:latest`.

## Profiles and state

Default persistent home:

```text
data/ -> /home/coder
```

Default profile state:

```text
data/.omp/agent/
```

Named profile state:

```text
data/.omp/profiles/<name>/agent/
```

The launcher refuses a symlinked persistent-home root before creating or seeding
state, including spellings ending in `/`, `/.`, or repeated combinations of
those suffixes. Real directory roots with the same suffixes remain accepted;
ancestor directory aliases are not blanket-rejected.

Profile selection order:

1. Last native `--profile`.
2. `--pi-profile`.
3. Defined `OMP_PROFILE`, even when empty.
4. Defined `PI_PROFILE`.
5. `OMPD_PROFILE`.
6. `default`.

`default`, empty, or whitespace selects the default profile. Named profiles must
be lowercase, start with a letter or digit, and contain only letters, digits,
dots, underscores, or hyphens. Trailing dots, path separators, uppercase, and
reserved device names are rejected.

The wrapper sets native profile environment variables instead of injecting
profile flags, so subcommands keep native parsing behavior.

Profile extraction follows the pinned native bootstrap: option values are not
profile flags, native `--` ends extraction, and a registered non-launch command
in the first remaining argument position owns everything after it. Explicit
`launch` and `acp` continue profile extraction. Leading launch options can make
a later command eligible for native dispatch without creating that early
profile boundary.

## Configuration

`config/config.yml` is a **first-launch seed**, not a recurring overlay. The
launcher copies it to the selected profile's writable native `config.yml` only
when no native `config.yml`, `config.yaml`, or legacy `settings.json` exists.
Existing files are preserved, even when empty.

Optional `config/profiles/<profile>.yml` files are standalone first-launch seeds
for their matching profiles. If present, that file is copied instead of the
base seed; the two are not merged. Omitted settings use native defaults.

Seeds are copied as-is: the wrapper does not inject model, browser, or concurrency
preferences. Native `task.maxConcurrency` defaults to 32 unless a seed or saved
settings sets it explicitly.

After seeding, use native `/settings`, `config set`, or edit the persisted file:

| Profile | Host config path |
| --- | --- |
| Default | `data/.omp/agent/config.yml` |
| Named | `data/.omp/profiles/<name>/agent/config.yml` |

For example:

```bash
./pi -- config set task.maxConcurrency 4
./pi --pi-profile work -- login
./pi --pi-profile work -- config path
```

These changes survive restarts. Editing a repository seed affects only profiles
that have not been initialized; existing profiles are not migrated or reseeded.
Existing homes keep their saved settings when upgrading from the old overlay
workflow. Review those saved settings if you previously relied on an overlay.

The wrapper does not load `config.local.yml` or inject/forward `PI_CONFIG_FILES`.
Explicit native `--config` remains an opt-in overlay with native precedence.
Repository config is still mounted read-only at `/config/ompd` for such explicit
paths. MCP configuration remains user-managed.

An optional `config/models.yml` is also seeded once, preserving existing
`models.yml`, `models.yaml`, or `models.json`, including empty files.

The bundled standalone `ollama` seed maps the main session and native task
agents to a local Ollama model, with task concurrency four:

```bash
pi --pi-profile ollama
OLLAMA_BASE_URL=http://host.docker.internal:11434 pi --pi-profile ollama
```

## Environment

Useful wrapper variables:

| Variable | Purpose |
| --- | --- |
| `OMPD_IMAGE` | Docker image tag; default `ompd:latest` |
| `OMPD_BASE_IMAGE` | Build-only Debian/toolchain image tag; default `ompd-base:latest` |
| `OMPD_DATA_DIR` | Absolute persistent home path |
| `OMPD_PROFILE` | Wrapper default profile |
| `OMP_PROFILE`, `PI_PROFILE` | Native profile defaults |
| `OMPD_DISPLAY` | Override display forwarding; empty disables it |
| `OMPD_NO_BANNER` | Suppress launch summary |

Provider variables are forwarded only when set and only by name:

```text
OPENAI_API_KEY OPENAI_CODEX_OAUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_OAUTH_TOKEN
GEMINI_API_KEY GOOGLE_API_KEY OPENROUTER_API_KEY GROQ_API_KEY
MISTRAL_API_KEY XAI_API_KEY DEEPSEEK_API_KEY OLLAMA_API_KEY
OLLAMA_HOST OLLAMA_BASE_URL AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN AWS_REGION AWS_DEFAULT_REGION AWS_PROFILE
```

Host credential files are not mounted automatically. Docker users with access to
container metadata may still inspect container environment variables.

## Cache cleanup

```bash
./clearcache --dry-run
./clearcache
```

Only contents of `$OMPD_DATA_DIR/.cache` are removed. `.omp` auth, settings,
profiles, models, and sessions are preserved. Symlinked home or `.cache` roots
are refused, including trailing `/` and `/.` spellings of a linked home root.
Symlinks inside `.cache` are unlinked, not followed.

## Browser, MCP, and display

Native browser automation uses the image browser via
`PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/playwright-chromium`. The launcher
suppresses Chrome for Testing's informational banner in headed windows; it does
not change the browser build or hide page-level permission prompts.

The portable seed enables native browser automation with `browser.enabled: true`
and selects headed operation with `browser.headless: false`. Existing profiles
keep their saved settings; enable `browser.enabled` in native `/settings` if needed.
Upstream defaults to headless when no preference is set. Headed use needs a working
X11 or XQuartz display:

```text
browser.open({headed:true,url:'https://example.com'})
```

Playwright MCP is installed but is not registered automatically. Its configuration
remains user-managed and is separate from native browser settings.

## Security limits

The container runs as `coder`, with `no-new-privileges`, dropped capabilities
except `CHOWN`, `SETUID`, and `SETGID`, host networking, and no Docker socket.

This is not a sandbox. Tools can modify the mounted project and persistent home.
Host networking and X11/XQuartz forwarding expose host services or desktop
access. Disable display forwarding with:

```bash
OMPD_DISPLAY='' pi
```

## Verification

Local checks:

```bash
bash -n pi build clearcache
python3 tests/run
```

These tests mock Docker. They validate wrapper behavior, not real image builds
or native runtime behavior.
The split build has not been validated with real amd64/arm64 image builds here;
both architectures require actual builds and runtime smoke checks.

Docker smoke checks on a Docker-enabled host:

```bash
./build
docker run --rm --entrypoint /bin/bash ompd:latest -lc '
  set -e
  for tool in git ssh rg fd fzf jq yq python basedpyright-langserver pytest \
    go gcc make cmake terraform terraform-ls node npm tsc \
    typescript-language-server vue-language-server intelephense ast-grep biome \
    playwright-mcp playwright-ffmpeg ffmpeg pdftotext qpdf ocrmypdf tesseract; do
    command -v "$tool"
  done
  omp --version
  playwright-chromium --version
'

smoke_home="$(mktemp -d)"
OMP_PROFILE=default OMPD_DATA_DIR="$smoke_home" OMPD_DISPLAY='' ./pi -- --version
OMPD_DATA_DIR="$smoke_home" OMPD_DISPLAY='' ./pi --pi-profile smoke -- --help
test -f "$smoke_home/.omp/agent/config.yml"
test -f "$smoke_home/.omp/profiles/smoke/agent/config.yml"
```

Do not use real auth/session data for smoke tests.
