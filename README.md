# opd

Docker wrapper for native [oh-my-pi](https://github.com/can1357/oh-my-pi).
Run omp from any project with persistent settings and a ready-to-use development environment.
The image includes development tools, Chromium/FFmpeg, Playwright MCP, and CodeMap.

## Quick start

Requirements: Docker, Bash, and `sha256sum` or `shasum` on Linux or macOS.

```bash
./build
./opd -- login                 # Authenticate with your provider
./opd
```

Run `/path/to/opd/opd` from another project, or install a launcher symlink:

```bash
mkdir -p ~/.local/bin
ln -s "$(pwd -P)/opd" ~/.local/bin/opd
```

The current project is mounted read/write under a stable `/workspaces/...` path.
The repository contains configuration templates, not provider credentials.

## Build and update

```bash
./build                       # Build omp; reuse the existing toolchain image
./build --no-cache            # Reinstall omp without rebuilding the toolchain
./build --base && ./build     # Rebuild tools/browser, then omp
./build --build-arg OMP_VERSION=18.14.1  # Example explicit version override
```

The default omp version is in `Dockerfile`. `./build` creates the base image if
missing; otherwise it reuses it. Changes to `Dockerfile.base` or
`playwright-chromium-launcher` require rebuilding both images.
Linux uses the host UID/GID by default; macOS uses `1000:1000`.
Existing persistent data must be writable by the image user.

## Usage

```bash
opd --opd-help                 # Wrapper help; no Docker required
opd -- --help                  # Native omp help
opd -- --print 'Explain this project'
printf 'Explain this project\n' | opd -- --print
opd -- --mode rpc
opd --opd-profile work
opd --opd-debug                # Keep the container; show inspection hints
```

`--` ends wrapper parsing; native arguments are forwarded literally.
Diagnostics go to stderr; native stdout and Docker exit status are preserved.
Docker keeps stdin attached and allocates a TTY only for interactive text/rpc-ui
launches. Print/RPC/ACP output is not mixed with wrapper banners.

## Persistent state and profiles

`data/` is the persistent container home (`/home/coder`). Authentication, settings,
models, sessions, and user assets survive restarts. **Never commit or share this home.**
Each clone has its own home unless `OPD_DATA_DIR` points elsewhere.

| Profile | Host state directory |
| --- | --- |
| Default | `data/.omp/agent/` |
| Named | `data/.omp/profiles/<name>/agent/` |

Select profiles with `--opd-profile` or native `--profile`; conflicting explicit
names are rejected. Environment fallback is `OMP_PROFILE` > `OPD_PROFILE` > default.
A defined empty `OMP_PROFILE` selects default. Names use lowercase letters/digits,
dots, underscores, and hyphens; start with a letter/digit. Invalid names are rejected.
Runtime sockets use ephemeral container-local tmpfs, not persistent storage.

## Configuration

`config/config.yml` is copied once when a profile is first initialized.
A matching `config/profiles/<name>.yml` replaces that seed without merging.
Existing profiles are never reseeded; edits to repository templates affect new profiles only.
Optional models and personality templates are also first-launch seeds.

After initialization, use native `/settings`, `config set`, or the profile's saved
`config.yml`. Those changes persist across container restarts.

```bash
opd --opd-profile work -- login
opd --opd-profile work -- config path
```

Repository config is mounted read-only at `/config/opd` for explicit config paths.
Playwright MCP is installed but not auto-registered; MCP configuration is user-managed.
CodeMap is available as a CLI, not an automatically invoked native tool.

## Environment

| Variable | Purpose |
| --- | --- |
| `OPD_IMAGE` | Runtime/build image tag; default `opd:latest` |
| `OPD_BASE_IMAGE` | Build-only toolchain image tag; default `opd-base:latest` |
| `OPD_DATA_DIR` | Override persistent home with an absolute path |
| `OMP_PROFILE` / `OPD_PROFILE` | Native/wrapper profile defaults; native takes precedence |
| `OPD_DISPLAY` | Override display forwarding; empty disables it |
| `OPD_GPU` | Graphics mode; default `off` |
| `OPD_ACCEPT_GPU_RISK=1` | Explicitly accept known DRI/software risks for this launch |
| `OPD_NO_BANNER=1` | Hide the banner, not security warnings |

Allowlisted provider environment variables are forwarded by name, including
`OPENAI_CODEX_OAUTH_TOKEN` and supported API keys/Ollama endpoint variables.
Host credential files and host omp/XDG configuration paths are not mounted automatically.

## Browser and GPU

| `OPD_GPU` | Behavior |
| --- | --- |
| `off` | GPU disabled; WebGL unavailable |
| `nvidia` | Linux; NVIDIA drivers, Container Toolkit, and CDI `nvidia.com/gpu=all` required |
| `dri` | Linux; usable `/dev/dri/renderD*` devices required; device groups are added |
| `software` | Explicit CPU-based SwiftShader; enables `--enable-unsafe-swiftshader` |

**Automatic SwiftShader fallback is disabled in every mode.** Select graphics
through `OPD_GPU`; conflicting browser graphics overrides are rejected.
Hardware device access alone does not prove accelerated rendering.

`dri` and `software` have run with unsandboxed GPU processes in our tests.
Every launch in these modes requires typing **`ACCEPT`** on an interactive terminal.
Noninteractive/print/RPC/ACP launches require `OPD_ACCEPT_GPU_RISK=1` instead.
Acceptance is not saved, forwarded into the container, or a sandbox fix.
This is a conservative mode-based warning, not automatic sandbox detection.

```bash
OPD_GPU=nvidia OPD_DISPLAY='' opd
OPD_ACCEPT_GPU_RISK=1 OPD_GPU=dri OPD_DISPLAY='' opd
```

GPU mode does not select visibility. Native `browser.headless` or per-call `headed`
controls it; the seed defaults to headed. Use `headed:false` without a display.
Headed Linux needs X11. macOS needs Docker Desktop and XQuartz with network clients
and local connections permitted; Docker Desktop does not expose the Mac GPU.
An xrdp display alone does not establish hardware GPU availability.

### Verify the browser

Use browser-level CDP diagnostics, not a webpage's potentially masked renderer string:

```js
const tab = await browser.open({name: "graphics-check", url: "about:blank", headed: false});
console.log(await tab.run(async ({browser}) => {
  const cdp = await browser.target().createCDPSession();
  try {
    const {gpu} = await cdp.send("SystemInfo.getInfo");
    return {renderer: gpu.auxAttributes?.glRenderer,
      sandboxed: gpu.auxAttributes?.sandboxed, webgl: gpu.featureStatus.webgl};
  } finally { await cdp.detach(); }
}));
await tab.goto("chrome://sandbox");
console.log(await tab.text());
await browser.close({name: "graphics-check"});
```

Hardware modes should identify the real GPU, not SwiftShader or llvmpipe.
Check GPU-process sandboxing separately: `chrome://sandbox` alone does not prove it.

## Security limits

The container runs as non-root with restricted capabilities, `no-new-privileges`,
and the required bundled `browser-seccomp.json`. Keep that file beside `opd`;
it is not downloaded at launch. Sandbox-disabling browser flags are blocked,
but Chromium can still skip GPU-process sandboxing: verify the running browser.

Host networking, GPU devices, and X11/XQuartz expose host services, drivers, or
desktop access. Tools can modify mounted projects and home contents.
**This development container is not a sandbox for untrusted code.**

## Maintenance and troubleshooting

- Preview cache cleanup with `./clearcache --dry-run`; run `./clearcache` to apply it.
  Only `.cache` contents are deleted; auth, settings, sessions, and user assets remain.
- Missing tools/browser changes: rebuild with `./build --base && ./build`.
- SSH or no display: set `OPD_DISPLAY=''` and open browsers with `headed:false`.
- Missing icons: select a patched Nerd Font in the host terminal, or choose
  Unicode/ASCII symbols in native `/settings`. Container fonts do not fix terminal icons.
- GPU initialization failures: fix host driver/device setup; do not disable sandboxing.

```bash
bash -n opd build clearcache
sh -n playwright-chromium-launcher
python3 tests/run
python3 tests/browser-launcher
```

Hermetic tests mock Docker; they do not replace actual image builds or runtime checks.
Verify each host, architecture, graphics mode, and display path you intend to use.
