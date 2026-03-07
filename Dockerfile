# Use an official ggml-org/llama.cpp image as the base image
FROM ghcr.io/ggml-org/llama.cpp:server-cuda

ENV PYTHONUNBUFFERED=1

# Set up the working directory
WORKDIR /

RUN rm -f /etc/apt/sources.list.d/cuda*.list /etc/apt/sources.list.d/nvidia*.list || true

# Erotica
# RUN mkdir -p /models && \
#    curl -L -o /models/Satyr-V0.1-4B-Q8_0.gguf \
#    https://huggingface.co/PantheonUnbound/Satyr-V0.1-4B/resolve/main/Satyr-V0.1-4B-Q8_0.gguf
    
# Usage (curl flags):
# -L: follow redirects
# --fail: exit nonzero on HTTP errors
# --retry <n>: retry up to n times on transient errors
# --retry-delay <sec>: wait between retries
# --retry-all-errors: retry on more than just "transient" defaults
# --continue-at -: resume from existing output file size
# --speed-time <sec> / --speed-limit <bytes>: abort if too slow for too long (forces retry)
# -o <file>: output path
#RUN mkdir -p /models && \
#    MODEL_URL="https://huggingface.co/bartowski/Qwen2.5-72B-Instruct-GGUF/resolve/main/Qwen2.5-72B-Instruct-Q3_K_L.gguf" && \
#    MODEL_PATH="/models/Qwen2.5-72B-Instruct-Q3_K_L.gguf" && \
#    TMP_PATH="${MODEL_PATH}.partial" && \
#    echo "Downloading model to ${TMP_PATH} ..." && \
#    rm -f "${TMP_PATH}.etag" && \
#    curl -L --fail \
#      --retry 30 --retry-delay 5 --retry-all-errors \
#      --connect-timeout 30 --max-time 0 \
#      --speed-time 60 --speed-limit 1048576 \
#      --continue-at - \
#      -o "${TMP_PATH}" \
#      "${MODEL_URL}" && \
#    mv "${TMP_PATH}" "${MODEL_PATH}"

RUN apt-get update --yes --quiet && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
    software-properties-common \
    gpg-agent \
    build-essential apt-utils \
    && apt-get install --reinstall ca-certificates \
    && add-apt-repository --yes ppa:deadsnakes/ppa && apt update --yes --quiet \
    && DEBIAN_FRONTEND=noninteractive apt-get install --yes --quiet --no-install-recommends \
    python3.11 \
    python3.11-dev \
    python3.11-distutils \
    python3.11-lib2to3 \
    python3.11-gdbm \
    python3.11-tk \
    bash \
    curl && \
    ln -s /usr/bin/python3.11 /usr/bin/python && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /work

# Add ./src as /work
ADD ./src /work

# Install runpod and its dependencies
RUN pip install -r ./requirements.txt && chmod +x /work/start.sh

# Set the entrypoint
ENTRYPOINT ["/bin/bash", "-c", "/work/start.sh"]
