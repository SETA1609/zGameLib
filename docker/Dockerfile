FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    python3 \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:${PATH}"

ARG ZIG_VERSION=0.17.0
# Zig, pinned. The tarball URL comes from the official release index, because
# the file naming changed (zig-x86_64-linux-<version> since 0.14).
RUN set -eux; \
    url="$(curl -fsSL https://ziglang.org/download/index.json \
      | python3 -c "import sys,json;print(json.load(sys.stdin)['${ZIG_VERSION}']['x86_64-linux']['tarball'])")"; \
    curl -fsSL "$url" -o /tmp/zig.tar.xz; \
    mkdir -p /opt/zig; tar -xJf /tmp/zig.tar.xz -C /opt/zig --strip-components=1; \
    ln -s /opt/zig/zig /usr/local/bin/zig; rm /tmp/zig.tar.xz; zig version

# Display + software Vulkan for the integration tests; glslc for hello-triangle;
# libshaderc-dev for -Dshaderc (the Vulkan adapter links the system shaderc).
# glslc and libshaderc-dev are in Ubuntu's universe component.
RUN sed -i 's/^Components: .*/Components: main universe/' /etc/apt/sources.list.d/ubuntu.sources \
    && apt-get update && apt-get install -y --no-install-recommends \
    libvulkan1 \
    mesa-vulkan-drivers \
    xvfb \
    glslc \
    libshaderc-dev \
    && rm -rf /var/lib/apt/lists/*

ENV DISPLAY=:99

WORKDIR /workspace
ENTRYPOINT ["/workspace/scripts/build-in-docker.sh"]
