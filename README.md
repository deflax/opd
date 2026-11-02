# opd

Docker wrapper for native [oh-my-pi](https://github.com/can1357/oh-my-pi).
Runs your current project with development tools, Chromium/FFmpeg, Playwright MCP, and CodeMap.
Requires Docker, Bash, and `sha256sum` or `shasum` on Linux or macOS.

## Quick start

```bash
./build
./opd -- login                 # Authenticate with your provider
./opd
```

Run `/path/to/opd/opd` from any project, or symlink it into your PATH.
The project is mounted read/write under a stable `/workspaces/...` path.

## Build and update

```bash
./build                       # Build omp; reuse the existing toolchain image
./build --base && ./build     # Rebuild tools/browser, then omp
./build --build-arg OMP_VERSION=<version>
```

The default omp version is in `Dockerfile`. Rebuild both images after changes to
`Dockerfile.base` or `playwright-chromium-launcher`. Linux uses the host UID/GID;
macOS uses `1000:1000`. Existing persistent data must be writable by that user.

## Usage

```bash
./opd --opd-help               # Wrapper options; no Docker required
./opd -- --help                # Native omp help
./opd -- --print 'Explain this project'
./opd -- --mode rpc
./opd --opd-profile work
./opd --opd-debug              # Keep the container; show inspection hints
```

`--` ends wrapper parsing; native arguments are forwarded literally.
Diagnostics go to stderr; native stdout and Docker exit status are preserved.
For Nerd Font icons, install and select a patched font in your host terminal.

## Persistent state and configuration

`data/` is the persistent container home (`/home/coder`): auth, settings, models,
sessions, and user assets survive restarts. **Never commit or share this home.**
Default profile state: `data/.omp/agent/`; named: `data/.omp/profiles/<name>/agent/`.
Runtime sockets use ephemeral container-local tmpfs, not persistent storage.

Select profiles with `--opd-profile` or native `--profile`; conflicting explicit names are rejected.
Environment fallback: `OMP_PROFILE` > `OPD_PROFILE` > default; an empty `OMP_PROFILE` selects default.
`config/config.yml` seeds new profiles once; `config/profiles/<name>.yml`, when
present, replaces that seed without merging. Existing profiles are never reseeded.
After initialization, use native `/settings` or `config set`; saved settings win.
Repository config is available read-only at `/config/opd`. MCP registration is user-managed.

Use `OPD_DATA_DIR` for an alternative absolute home path and `OPD_DISPLAY` to
override display forwarding (empty disables it). `OPD_NO_BANNER=1` hides only the banner.

## Browser and GPU

| `OPD_GPU` | Behavior |
| --- | --- |
| `off` (default) | GPU disabled; WebGL unavailable |
| `nvidia` | Linux; NVIDIA drivers, Container Toolkit, and CDI `nvidia.com/gpu=all` required |
| `dri` | Linux; usable `/dev/dri/renderD*` devices required |
| `software` | Explicit SwiftShader; enables `--enable-unsafe-swiftshader` |

**Automatic SwiftShader fallback is disabled in every mode.**
`dri` and `software` have run with unsandboxed GPU processes in our tests.
Each launch requires typing **`ACCEPT`**; noninteractive/print/RPC/ACP launches
must instead set `OPD_ACCEPT_GPU_RISK=1`. Acceptance is not saved or a sandbox fix.

```bash
OPD_GPU=nvidia OPD_DISPLAY='' ./opd
OPD_ACCEPT_GPU_RISK=1 OPD_GPU=dri OPD_DISPLAY='' ./opd
```

GPU mode does not select visibility. Native `browser.headless` or per-call `headed`
controls it; the seed defaults to headed. Use `headed:false` without a display.
Headed Linux needs X11; macOS needs Docker Desktop and XQuartz with network clients
and local connections permitted. Docker Desktop does not expose the Mac GPU.

## Security and maintenance

Host networking, GPU devices, and X11/XQuartz weaken isolation. Tools can modify
mounted projects and home contents: this is not a sandbox for untrusted code.
Keep `browser-seccomp.json` beside `opd`; it is required and never downloaded at launch.
Sandbox-disabling flags are blocked, but verify `chrome://sandbox` and GPU-process
sandbox status separately: the sandbox page alone does not prove GPU sandboxing.

`./clearcache --dry-run` previews cleanup; `./clearcache` deletes only `.cache` contents.
Auth, settings, sessions, and other home assets are preserved.
Checks: `bash -n opd build clearcache`, `sh -n playwright-chromium-launcher`,
`python3 tests/run`, and `python3 tests/browser-launcher`. Hermetic tests do not replace real builds/runtime checks.
