# Debian oldstable (Bullseye)
FROM debian:oldstable

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    libsdl2-dev \
    rsync \
    wget \
    zip \
    git \
    ca-certificates \
    bash \
 && rm -rf /var/lib/apt/lists/*

# Headless environment (no real sound or display)
ENV XDG_RUNTIME_DIR=/tmp/runtime \
    SDL_AUDIODRIVER=dummy \
    SDL_VIDEODRIVER=dummy

RUN mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

# Everything goes in /app
WORKDIR /app
COPY . .

# Build uxn (Linux) directly in /app
RUN set -eux; \
    ./build.sh --no-run

# Build “essentials” ROMs directly into /app/essentials/uxn
RUN set -eux; \
    mkdir -p /app/essentials/uxn; \
    entries=" \
      uxn/projects/software/calc.tal \
      uxn/projects/software/launcher.tal \
      uxn/projects/examples/demos/piano.tal \
      uxn/projects/examples/software/clock.tal \
      catclock/src/catclock.tal \
      dexe/src/dexe.tal \
      donsol/src/main.tal \
      left/src/left.tal \
      nasu/src/nasu.tal \
      noodle/src/noodle.tal \
      orca-toy/src/orca.tal:orca.rom \
      turye/src/turye.tal \
    "; \
    for F in $entries; do \
      PROJECT="${F%%/*}"; \
      SRC="$F"; \
      if [[ "$F" == *:* ]]; then \
        ROMNAME="${F##*:}"; \
        SRC="${F%:*}"; \
      else \
        base="${F##*/}"; \
        ROMNAME="${base%.tal}.rom"; \
        [[ "$ROMNAME" != "main.rom" ]] || ROMNAME="${PROJECT}.rom"; \
      fi; \
      if [[ ! -d "/app/$PROJECT" ]]; then \
        echo "Skipping missing project: $PROJECT"; \
        continue; \
      fi; \
      echo "== Assembling: $SRC -> /app/essentials/uxn/${ROMNAME}"; \
      (cd "/app/$PROJECT" && /app/bin/uxnasm "${SRC#*/}" "/app/essentials/uxn/${ROMNAME}") \
        || echo "Failed: $SRC"; \
    done; \
    echo ""; \
    echo "✅ Build finished."; \
    echo "Binaries in: /app/bin"; \
    echo "ROMs in:     /app/essentials/uxn"

# Show both binaries and ROMs
CMD ["bash", "-lc", "echo -e '\\n== /app/bin =='; ls -l /app/bin || true; echo -e '\\n== /app/essentials/uxn =='; ls -l /app/essentials/uxn || true"]
# Debian oldstable (Bullseye)
FROM debian:oldstable

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    libsdl2-dev \
    rsync \
    wget \
    zip \
    git \
    ca-certificates \
    bash \
 && rm -rf /var/lib/apt/lists/*

# Headless environment (no real sound or display)
ENV XDG_RUNTIME_DIR=/tmp/runtime \
    SDL_AUDIODRIVER=dummy \
    SDL_VIDEODRIVER=dummy

RUN mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

# Everything goes in /app
WORKDIR /app
COPY . .

# Build uxn (Linux) directly in /app
RUN set -eux; \
    ./build.sh --no-run

# Build “essentials” ROMs directly into /app/essentials/uxn
RUN set -eux; \
    mkdir -p /app/essentials/uxn; \
    entries=" \
      uxn/projects/software/calc.tal \
      uxn/projects/software/launcher.tal \
      uxn/projects/examples/demos/piano.tal \
      uxn/projects/examples/software/clock.tal \
      catclock/src/catclock.tal \
      dexe/src/dexe.tal \
      donsol/src/main.tal \
      left/src/left.tal \
      nasu/src/nasu.tal \
      noodle/src/noodle.tal \
      orca-toy/src/orca.tal:orca.rom \
      turye/src/turye.tal \
    "; \
    for F in $entries; do \
      PROJECT="${F%%/*}"; \
      SRC="$F"; \
      if [[ "$F" == *:* ]]; then \
        ROMNAME="${F##*:}"; \
        SRC="${F%:*}"; \
      else \
        base="${F##*/}"; \
        ROMNAME="${base%.tal}.rom"; \
        [[ "$ROMNAME" != "main.rom" ]] || ROMNAME="${PROJECT}.rom"; \
      fi; \
      if [[ ! -d "/app/$PROJECT" ]]; then \
        echo "Skipping missing project: $PROJECT"; \
        continue; \
      fi; \
      echo "== Assembling: $SRC -> /app/essentials/uxn/${ROMNAME}"; \
      (cd "/app/$PROJECT" && /app/bin/uxnasm "${SRC#*/}" "/app/essentials/uxn/${ROMNAME}") \
        || echo "Failed: $SRC"; \
    done; \
    echo ""; \
    echo "✅ Build finished."; \
    echo "Binaries in: /app/bin"; \
    echo "ROMs in:     /app/essentials/uxn"

# Show both binaries and ROMs
CMD ["bash", "-lc", "echo -e '\\n== /app/bin =='; ls -l /app/bin || true; echo -e '\\n== /app/essentials/uxn =='; ls -l /app/essentials/uxn || true"]

