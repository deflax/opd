# ompd

Docker wrapper for native `omp`.

`./build` creates the image. `./pi` runs `omp` inside it with the current
project mounted under `/workspaces/...` and persistent state in `data/`.

## Quick start

```bash
./build
./pi

# Optional: install the launcher on PATH.
mkdir -p ~/.local/bin
ln -s "$(pwd -P)/pi" ~/.local/bin/pi
```

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

Wrapper options:

| Option | Behavior |
| --- | --- |
| `--pi-help` | Show wrapper help without Docker |
| `--pi-profile NAME` | Select native profile state and matching overlay |
| `--pi-debug` | Keep the container and print inspect/log/remove hints |

## Build

Requirements: Docker, Bash, and `sha256sum` or `shasum`.

```bash
./build
OMPD_IMAGE=my-ompd ./build
./build --build-arg USER_UID=1000 --build-arg USER_GID=1000
```

Linux builds use the host UID/GID by default. macOS builds use `1000:1000`
because Docker Desktop does not need the host account IDs inside the image.
Existing files under `data/` must be writable by the image user.

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

## Configuration

Repository config is mounted read-only at `/config/ompd`.

Overlay order, low to high:

1. Persistent native config in the selected profile.
2. `config/config.yml`.
3. `config/config.local.yml`, if present.
4. `config/profiles/<profile>.yml`, if present.
5. Explicit native `--config` files.

`config/config.yml` is also copied once into a new profile when no native config
already exists. Existing `config.yml`, `config.yaml`, `settings.json`,
`models.yml`, `models.yaml`, and `models.json` are preserved, including empty
files.

Overlay values reapply on each launch. If a value is set in an overlay, it can
override changes made later through native settings until the overlay is changed
or removed.

The bundled `ollama` profile maps the main session and native task agents to a
local Ollama model:

```bash
pi --pi-profile ollama
OLLAMA_BASE_URL=http://host.docker.internal:11434 pi --pi-profile ollama
```

## Environment

Useful wrapper variables:

| Variable | Purpose |
| --- | --- |
| `OMPD_IMAGE` | Docker image tag; default `ompd:latest` |
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
are refused. Symlinks inside `.cache` are unlinked, not followed.

## Browser, MCP, and display

Native browser automation uses the image browser via
`PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/playwright-chromium`.

Headless native browser use is the default. Headed use needs a working X11 or
XQuartz display:

```text
browser.open({headed:true,url:'https://example.com'})
```

`config/playwright-mcp.json` is an optional Playwright MCP launch config mounted
at `/config/ompd/playwright-mcp.json`. It is not registered automatically and is
not copied into native config. MCP remains user-managed.

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
