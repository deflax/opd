ARG BASE_IMAGE=opd-base:latest
FROM ${BASE_IMAGE}

ARG OMP_VERSION=18.9.2
ARG USER_UID=1000
ARG USER_GID=1000
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
