FROM debian:trixie-slim

ARG OMP_VERSION=18.4.10
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
        bash \
        binutils \
        binwalk \
        cairosvg \
        ca-certificates \
        composer \
        curl \
        file \
        gh \
        git \
        gnupg \
        imagemagick \
        iproute2 \
        jq \
        less \
        librsvg2-bin \
        nano \
        ncurses-term \
        fonts-noto-color-emoji \
        patch \
        php8.4-cli \
        php8.4-common \
        php8.4-curl \
        php8.4-imagick \
        php8.4-intl \
        php8.4-mbstring \
        php8.4-mysql \
        php8.4-pcov \
        php8.4-pgsql \
        php8.4-redis \
        php8.4-sqlite3 \
        php8.4-xml \
        php8.4-zip \
        python-is-python3 \
        python3 \
        python3-cryptography \
        python3-pip \
        python3-virtualenv \
        python3-venv \
        ripgrep \
        ruby \
        sqlite3 \
        tmux \
        tree \
        unzip \
        upx \
        xclip \
        xz-utils \
        yara \
        zip; \
    rm -f /usr/bin/sg; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/*

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
    rm -rf /var/lib/apt/lists/* /tmp/*

RUN set -eux; \
    arch="${TARGETARCH:-$(dpkg --print-architecture)}"; \
    case "$arch" in \
        amd64) \
            curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
                | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg; \
            chmod 0644 /etc/apt/keyrings/google-chrome.gpg; \
            printf 'deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main\n' \
                > /etc/apt/sources.list.d/google-chrome.list; \
            browser=google-chrome-stable ;; \
        arm64) browser=chromium ;; \
        *) echo "Unsupported architecture: $arch (expected amd64 or arm64)" >&2; exit 1 ;; \
    esac; \
    apt-get update; \
    apt-get install -y --no-install-recommends "$browser"; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/*

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
