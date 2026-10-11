FROM debian:trixie-slim

ARG OMP_VERSION=18.9.1
ARG TARGETARCH
ARG USER_UID=1000
ARG USER_GID=1000
RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
        amd64|arm64) ;; \
        *) echo "Unsupported architecture: $arch (expected amd64 or arm64)" >&2; exit 1 ;; \
    esac; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        bash \
        openssh-client \
        ripgrep \
        unzip \
        fzf \
        ncurses-term \
        iputils-ping \
        procps \
        xdg-utils \
        xclip \
        wl-clipboard \
        python3 \
        python-is-python3 \
        python3-pip \
        python3-venv \
        golang-go \
        gcc \
        libc6-dev \
        make \
        cmake \
        jq \
        yq \
        tree \
        file \
        zip \
        ffmpeg \
        poppler-utils \
        qpdf \
        ocrmypdf \
        tesseract-ocr \
        tesseract-ocr-eng \
        diffutils \
        fd-find \
        patch \
        tar \
        gzip \
        python3-pytest \
        python3-pydantic \
        python3-fastapi \
        gnupg; \
    ln -sf /usr/bin/fdfind /usr/local/bin/fd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --break-system-packages --no-cache-dir basedpyright \
    && command -v python \
    && python --version \
    && command -v basedpyright-langserver

RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
        amd64) hashicorp_arch="amd64" ;; \
        arm64) hashicorp_arch="arm64" ;; \
        *) echo "Unsupported architecture for Terraform tools: $arch" >&2; exit 1 ;; \
    esac; \
    terraform_version="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)"; \
    terraform_ls_version="$(curl -fsSL https://api.github.com/repos/hashicorp/terraform-ls/releases/latest | jq -r '.tag_name | ltrimstr("v")')"; \
    tmpdir="$(mktemp -d)"; \
    curl -fsSL "https://releases.hashicorp.com/terraform/${terraform_version}/terraform_${terraform_version}_linux_${hashicorp_arch}.zip" -o "$tmpdir/terraform.zip"; \
    unzip -q "$tmpdir/terraform.zip" -d "$tmpdir/terraform"; \
    install -m 0755 "$tmpdir/terraform/terraform" /usr/local/bin/terraform; \
    curl -fsSL "https://releases.hashicorp.com/terraform-ls/${terraform_ls_version}/terraform-ls_${terraform_ls_version}_linux_${hashicorp_arch}.zip" -o "$tmpdir/terraform-ls.zip"; \
    unzip -q "$tmpdir/terraform-ls.zip" -d "$tmpdir/terraform-ls"; \
    install -m 0755 "$tmpdir/terraform-ls/terraform-ls" /usr/local/bin/terraform-ls; \
    rm -rf "$tmpdir"; \
    terraform version; \
    terraform-ls version

RUN set -eux; \
    install -d -m 0755 /etc/apt/keyrings; \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; \
    chmod 0644 /etc/apt/keyrings/nodesource.gpg; \
    printf 'deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_24.x nodistro main\n' \
        > /etc/apt/sources.list.d/nodesource.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends nodejs; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

RUN npm install -g --prefix /usr/local \
    @playwright/mcp@latest \
    @ast-grep/cli@latest \
    @biomejs/biome@latest \
    @vue/language-server@latest \
    intelephense@latest \
    typescript@latest \
    typescript-language-server@latest

ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright

RUN npx @playwright/mcp install-browser chromium --with-deps \
    && CHROMIUM_BIN="$(find /ms-playwright -path '*/chrome-linux*/chrome' -type f | sort | tail -n 1)" \
    && FFMPEG_BIN="$(find /ms-playwright -path '*/ffmpeg-linux' -type f | sort | tail -n 1)" \
    && test -x "$CHROMIUM_BIN" \
    && test -x "$FFMPEG_BIN" \
    && ln -sf "$CHROMIUM_BIN" /usr/local/bin/playwright-chromium \
    && ln -sf "$FFMPEG_BIN" /usr/local/bin/playwright-ffmpeg \
    && chmod -R a+rX /ms-playwright \
    && test -x /usr/local/bin/playwright-chromium \
    && test -x /usr/local/bin/playwright-ffmpeg \
    && /usr/local/bin/playwright-chromium --version \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV PLAYWRIGHT_MCP_EXECUTABLE_PATH=/usr/local/bin/playwright-chromium \
    PUPPETEER_EXECUTABLE_PATH=/usr/local/bin/playwright-chromium

RUN set -eux; \
    curl -fsSL \
        "https://raw.githubusercontent.com/can1357/oh-my-pi/v${OMP_VERSION}/scripts/install.sh" \
        -o /tmp/install-omp.sh; \
    PI_INSTALL_DIR=/usr/local/bin \
        sh /tmp/install-omp.sh --binary --ref "v${OMP_VERSION}"; \
    rm -f /tmp/install-omp.sh; \
    omp --version

RUN set -eux; \
    for value in "$USER_UID" "$USER_GID"; do \
        case "$value" in \
            ''|*[!0-9]*) echo "USER_UID and USER_GID must be positive numeric IDs" >&2; exit 1 ;; \
        esac; \
        if ! [ "$value" -gt 0 ] || ! [ "$value" -le 2147483647 ]; then \
            echo "USER_UID and USER_GID must be between 1 and 2147483647" >&2; exit 1; \
        fi; \
    done; \
    if getent passwd "$USER_UID" >/dev/null || getent passwd coder >/dev/null; then \
        echo "Cannot create coder: UID $USER_UID or username coder is already in use; choose another USER_UID" >&2; \
        exit 1; \
    fi; \
    if ! getent group "$USER_GID" >/dev/null; then \
        if getent group coder >/dev/null; then \
            echo "Cannot create coder group: name coder is already in use with a different GID" >&2; \
            exit 1; \
        fi; \
        groupadd -g "$USER_GID" coder; \
    fi; \
    if [ -e /home/coder ] || [ -L /home/coder ]; then \
        echo "Cannot create coder: /home/coder already exists" >&2; exit 1; \
    fi; \
    useradd -m -d /home/coder -s /bin/bash -u "$USER_UID" -g "$USER_GID" coder

ENV HOME=/home/coder \
    USER=coder \
    LOGNAME=coder \
    PATH=/home/coder/.local/bin:/home/coder/.bun/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
WORKDIR /home/coder
USER ${USER_UID}:${USER_GID}
