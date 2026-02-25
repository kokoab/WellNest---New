# Use multi‑arch image (supports both Intel and Apple Silicon)
FROM ghcr.io/cirruslabs/flutter:stable

# Ensure the 'cirrus' user exists (UID/GID 1000, as typical)
RUN groupadd -g 1000 cirrus 2>/dev/null || true && \
    useradd -m -u 1000 -g cirrus -s /bin/bash cirrus 2>/dev/null || true

# Set working directory
WORKDIR /app

# (Optional) Switch to root to install extra system packages
USER root
RUN apt-get update && apt-get install -y \
    android-sdk-platform-tools \
    && apt-get clean
# Allow cirrus to write to Flutter SDK cache (version stamps, etc.)
RUN chown -R cirrus:cirrus /sdks/flutter 2>/dev/null || true

# Switch back to cirrus (the user your app should run as)
USER cirrus
# Prefer arm64 adb from apt over x86 one in ANDROID_HOME (fixes Rosetta ELF error on Apple Silicon)
ENV PATH="/usr/bin:$PATH"
# Git in the base image's /sdks/flutter is owned by root; mark it safe so 'flutter' commands work
RUN git config --global --add safe.directory /sdks/flutter

# Default command: keep container alive for interactive use
CMD ["sleep", "infinity"]