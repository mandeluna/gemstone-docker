FROM ubuntu:22.04

# --- Build Arguments ---
ARG GS_VER="3.7.4.3"
ARG GS_ARCH="x86_64.Linux"
ARG GS_DIR_NAME="GemStone64Bit${GS_VER}-${GS_ARCH}"

# --- Install Dependencies ---
# 'gosu' is critical for the entrypoint permissions fix
RUN apt-get update && apt-get install -y \
    unzip \
    ca-certificates \
    curl \
    net-tools \
    gosu \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# --- User Setup ---
RUN groupadd -r gemstone \
    && useradd -r -g gemstone -d /opt/gemstone -s /bin/bash gemstone

WORKDIR /opt/gemstone

# --- Download & Flatten ---
# 1. Download zip
# 2. Unzip (creates a subdir)
# 3. Move contents from subdir to root (.)
# 4. Remove empty subdir and zip
RUN curl -L -o gemstone.zip "https://ftp.gemtalksystems.com/GemStone64/${GS_VER}/${GS_DIR_NAME}.zip" \
    && unzip gemstone.zip \
    && mv ${GS_DIR_NAME}/* . \
    && rmdir ${GS_DIR_NAME} \
    && rm gemstone.zip

# --- Environment Variables ---
# Direct path mapping. No symlinks.
ENV GEMSTONE=/opt/gemstone
ENV PATH=$GEMSTONE/bin:$PATH
ENV GEMSTONE_NAME=gs64stone
ENV GEMSTONE_DATADIR=/opt/gemstone/data

# --- File System Setup ---
# Create data and locks directories
RUN mkdir -p data locks log \
    && chown -R gemstone:gemstone /opt/gemstone

# Setup Key File
RUN cp sys/community.starter.key sys/gemstone.key \
    && chmod 644 sys/gemstone.key \
    && chown gemstone:gemstone sys/gemstone.key

RUN ls -la $GEMSTONE/data

# --- Entrypoint & Healthcheck ---
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD gslist -l | grep -q $GEMSTONE_NAME || exit 1

VOLUME ["/opt/gemstone/data"]

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
