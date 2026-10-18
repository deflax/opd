# opd

Docker wrapper for native `omp`.

`./build` creates the image. `./opd` runs `omp` inside it with the current
project mounted under `/workspaces/...` and persistent state in `data/`.

## Quick start

On each machine, clone this repository, then:

```bash
./build
./opd -- login   # Configure provider authentication through native omp.
./opd

# Optional: install the launcher on PATH.
mkdir -p ~/.local/bin
ln -s "$(pwd -P)/opd" ~/.local/bin/opd
```

The repository supplies initial settings, not credentials. Each clone keeps its
own provider authentication and subsequent settings in its persistent `data/`
home. Do not commit or copy that home as part of the configuration template.

The project executable and wrapper interface are named `opd`.
Default image tags are `opd:latest` and `opd-base:latest`, so rebuild the images 
after upgrading.

Existing persistent data is unchanged. User-managed MCP configuration and
explicit native config paths remain opt-in; repository config is available at
`/config/opd`.

Use `OMP_PROFILE` for native profile selection. The upstream installer's build-time
`PI_INSTALL_DIR` is unrelated to the wrapper interface.

Common calls:

```bash
opd -- --help
opd -- --print 'Explain this project'
opd -- --mode rpc
opd --opd-profile work
opd --profile work
printf 'Explain this project\n' | opd -- --print
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

For prompt launches without a container TTY, terminal-origin stdin is replaced
with `/dev/null` so native startup reaches EOF instead of waiting for keyboard
input. This covers `--print`/`-p`, JSON output, and text launches with redirected
stdout. Actual pipes and redirected input files are preserved. RPC/ACP input and
subcommand stdin remain attached, including when `--print` is also present.

Interactive launches show a custom `opd` ASCII logo in the OCD style when
stderr is also a terminal, then start omp immediately without an intentional delay.
After Docker exits, the wrapper restores terminal state. Only a bare `opd`
launch (no command-line arguments) prints the full banner again (logo and launch
details) for interactive launches with terminal stderr, so it remains visible
even if the app cleared the screen or scrollback. Passing any arguments skips
this post-exit banner without changing startup output. Signal forwarding does
not reprint the banner while Docker may still be running.
Launch details report the image/container, selected
profile and persistent state path, terminal allocation, cleanup policy,
workspace/home/config mounts, ephemeral runtime sockets, display/X11 forwarding,
and host networking. Repository config is not a recurring settings overlay.

All startup diagnostics go to stderr, leaving native print/RPC/ACP stdout
untouched. The logo is omitted for print/protocol modes and non-terminal
launches. Prompts, native arguments, full Docker commands, and credential values
are never printed. Set `OPD_NO_BANNER=1` to suppress both the logo and launch
details; explicit `--opd-debug` inspection hints remain available.

Wrapper options:

| Option | Behavior |
| --- | --- |
| `--opd-help` | Show wrapper help without Docker |
| `--opd-profile NAME` | Select native profile state and its first-launch config seed |
| `--opd-debug` | Keep the container and print inspect/log/remove hints |

## Linux terminal fonts

Nerd Font icons require a patched font installed and selected on the **host**.
Fonts inside the Docker image do not affect your terminal's rendering. Configure
each machine separately; a working macOS font setup does not carry over to Linux.

For Debian with KDE Konsole:

1. Download **JetBrainsMono** from the [Nerd Fonts downloads](https://www.nerdfonts.com/font-downloads)
   and extract the archive.
2. Create the per-user font directory:
   ```bash
   mkdir -p ~/.local/share/fonts
   ```
   Copy the extracted `.ttf` files into that directory, then refresh the font cache:
   ```bash
   fc-cache -f
   ```
   If `fc-cache` is unavailable, install Debian's `fontconfig` package on the host.
3. In Konsole, open **Settings → Edit Current Profile → Appearance → Font**.
   Select **JetBrainsMono Nerd Font Mono**, not the unpatched **JetBrains Mono**.
   Reopen the font picker if the newly installed font is not listed.
4. In omp, open `/settings` and select **Symbol Preset → Nerd**. The repository
   seed uses `symbolPreset: nerd`, but existing profiles retain their persisted
   settings; editing the seed does not update them.

Check the font outside omp, directly in a Bash shell in Konsole:

```bash
fc-match 'JetBrainsMono Nerd Font Mono'
printf 'Powerline: \ue0b0  Folder: \uf07c  Branch: \ue0a0\n'
```

`fc-match` should report the patched font, not a fallback family such as DejaVu
Sans. Boxes in the glyph check indicate a host font/profile problem. If the icons
render correctly there but not in omp, check the selected profile's persisted
**Symbol Preset**. Alternatively, select **Unicode** or **ASCII** in omp to avoid
requiring a Nerd Font.

## Build

Requirements: Docker, Bash, and `sha256sum` or `shasum`.

```bash
./build
./build --no-cache                       # Reinstall omp without rebuilding Debian/tools
./build --base                          # Rebuild the Debian/toolchain image only
./build                                 # Build omp on the updated base
OPD_IMAGE=my-opd ./build
./build --build-arg USER_UID=1000 --build-arg USER_GID=1000
```

The default native omp version is [18.12.1](https://github.com/can1357/oh-my-pi/tree/v18.12.1).
Run `./build` to install it in a new runtime image; the existing base is reused.
Override the version with `./build --build-arg OMP_VERSION=<version>`.
The wrapper's mirrored profile/CLI tables were checked against that tag,
including `--restore` and the `auth`/`session` command boundaries.

Linux builds use the host UID/GID by default. macOS builds use `1000:1000`
because Docker Desktop does not need the host account IDs inside the image.
Existing files under `data/` must be writable by the image user.

The image is built from two separate Dockerfiles:

- `Dockerfile.base` builds `opd-base:latest` from Debian, including the development
  tools, Node, Playwright MCP, and managed Chromium/FFmpeg.
- `Dockerfile` builds `opd:latest` from that base, installing native omp and
  creating the UID/GID-mapped runtime user.

The base includes C/C++ build tools (`build-essential`, CMake, Ninja, and
pkg-config), Python development headers and venv support, ALSA/JACK development
libraries, the PortAudio runtime (`libportaudio2`), and X11, Xext, Xinerama,
Xrandr, Xcursor, FreeType, and Fontconfig development libraries.

`./build` creates the base automatically if its tag is absent locally; otherwise
it reuses it without rebuilding it. Changes to `Dockerfile.base` or
`playwright-chromium-launcher` require an explicit `./build --base`, followed by
`./build`. To refresh all base dependencies, use `./build --base --pull --no-cache`.
Changing omp's version or runtime UID/GID does not rebuild the toolchain.

Set `OPD_BASE_IMAGE` to select a different base tag for both build commands.
Docker options apply only to the selected build; the automatic missing-base build
uses defaults. For cross-architecture builds, build a matching base explicitly
first and use separate tags for each architecture:

```bash
OPD_BASE_IMAGE=opd-base:amd64 ./build --base --platform linux/amd64
OPD_BASE_IMAGE=opd-base:amd64 OPD_IMAGE=opd:amd64 ./build --platform linux/amd64
OPD_BASE_IMAGE=opd-base:arm64 ./build --base --platform linux/arm64
OPD_BASE_IMAGE=opd-base:arm64 OPD_IMAGE=opd:arm64 ./build --platform linux/arm64
```

Direct Docker builds must also build or pull the base first, then select it with
`docker build --build-arg BASE_IMAGE=...` when not using `opd-base:latest`.

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

Native transient runtime directories are mounted on container-local tmpfs:
`/home/coder/.omp/run` and, for a named profile, its
`/home/coder/.omp/profiles/<name>/run`. This keeps daemon sockets off host-shared
filesystems that reject socket permission changes. Runtime state is discarded
when the container stops; existing host runtime files are hidden, not deleted.
Auth, settings, models, sessions, and user assets remain persistent.

The launcher refuses a symlinked persistent-home root before creating or seeding
state, including spellings ending in `/`, `/.`, or repeated combinations of
those suffixes. Real directory roots with the same suffixes remain accepted;
ancestor directory aliases are not blanket-rejected.

Profile selection order:

1. Last native `--profile`.
2. `--opd-profile`.
3. Defined `OMP_PROFILE`, even when empty.
4. `OPD_PROFILE`.
5. `default`.

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
./opd -- config set task.maxConcurrency 4
./opd --opd-profile work -- login
./opd --opd-profile work -- config path
```

These changes survive restarts. Editing a repository seed affects only profiles
that have not been initialized; existing profiles are not migrated or reseeded.
Existing homes keep their saved settings when upgrading from the old overlay
workflow. Review those saved settings if you previously relied on an overlay.

The wrapper does not load `config.local.yml` or inject/forward `PI_CONFIG_FILES`.
Explicit native `--config` remains an opt-in overlay with native precedence.
Repository config is still mounted read-only at `/config/opd` for such explicit
paths. MCP configuration remains user-managed.

An optional `config/models.yml` is also seeded once, preserving existing
`models.yml`, `models.yaml`, or `models.json`, including empty files.

`config/PERSONALITY.md` provides a custom text personality, seeded only for newly initialized profiles.

The bundled standalone `ollama` seed maps the main session and native task
agents to a local Ollama model, with task concurrency four:

```bash
opd --opd-profile ollama
OLLAMA_BASE_URL=http://host.docker.internal:11434 opd --opd-profile ollama
```

## Environment

Useful wrapper variables:

| Variable | Purpose |
| --- | --- |
| `OPD_IMAGE` | Docker image tag; default `opd:latest` |
| `OPD_BASE_IMAGE` | Build-only Debian/toolchain image tag; default `opd-base:latest` |
| `OPD_DATA_DIR` | Absolute persistent home path |
| `OPD_PROFILE` | Wrapper default profile |
| `OMP_PROFILE` | Native profile default; defined empty selects default |
| `OPD_DISPLAY` | Override display forwarding; empty disables it |
| `OPD_NO_BANNER` | Any nonempty value suppresses the logo and launch details |

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

Only contents of `$OPD_DATA_DIR/.cache` are removed. `.omp` auth, settings,
profiles, models, and sessions are preserved. Symlinked home or `.cache` roots
are refused, including trailing `/` and `/.` spellings of a linked home root.
Symlinks inside `.cache` are unlinked, not followed.

## Browser, MCP, and display

Native browser automation uses the image browser via
`PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/playwright-chromium`. The launcher
suppresses Chrome for Testing's informational banner in headed windows and disables
GPU acceleration to avoid observed container/X11 DRI3/nouveau hangs. This trades
hardware acceleration for reliable rendering; it does not change the browser build
or hide page-level permission prompts. Launcher changes require `./build --base`
followed by `./build` to take effect in the image.

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
OPD_DISPLAY='' opd
```

## Verification

Local checks:

```bash
bash -n opd build clearcache
python3 tests/run
```

These tests mock Docker. They validate wrapper behavior, not real image builds
or native runtime behavior.
The split build has not been validated with real amd64/arm64 image builds here;
both architectures require actual builds and runtime smoke checks.

Docker smoke checks on a Docker-enabled host:

```bash
./build
docker run --rm --entrypoint /bin/bash opd:latest -lc '
  set -e
  for tool in git ssh rg fd fzf jq yq python basedpyright-langserver pytest \
    go gcc g++ make cmake ninja pkg-config terraform terraform-ls node npm tsc \
    typescript-language-server vue-language-server intelephense ast-grep biome \
    playwright-mcp playwright-ffmpeg ffmpeg pdftotext qpdf ocrmypdf tesseract; do
    command -v "$tool"
  done
  pkg-config --exists alsa jack x11 xext xinerama xrandr xcursor freetype2 fontconfig
  printf "%s\n" "#include <iostream>" \
    "int main() { std::cout << 42 << std::endl; }" \
    | g++ -x c++ - -o /tmp/opd-cpp-smoke
  test "$(/tmp/opd-cpp-smoke)" = 42
  rm /tmp/opd-cpp-smoke
  omp --version
  playwright-chromium --version
'

smoke_home="$(mktemp -d)"
OMP_PROFILE=default OPD_DATA_DIR="$smoke_home" OPD_DISPLAY='' ./opd -- --version
OPD_DATA_DIR="$smoke_home" OPD_DISPLAY='' ./opd --opd-profile smoke -- --help
test -f "$smoke_home/.omp/agent/config.yml"
test -f "$smoke_home/.omp/profiles/smoke/agent/config.yml"
```

Do not use real auth/session data for smoke tests.
