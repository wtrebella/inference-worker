#!/usr/bin/env bash
set -euo pipefail

echo "image ready, initializing model files"

# -------- env --------
LLAMA_CACHED_MODEL="${LLAMA_CACHED_MODEL:-}"
LLAMA_CACHED_GGUF_PATH="${LLAMA_CACHED_GGUF_PATH:-model.gguf}"

cleanup() {
    echo "start.sh: Cleaning up..."
    pkill -P $$ # kill all child processes of the current script
    exit 0
}

# -------- probe likely HuggingFace cache roots --------
# (RunPod and many images mount the HF hub cache in one of these)
declare -a PROBE_DIRS=(
  "${CACHE_DIR:-}"
  "${HUGGINGFACE_HUB_CACHE:-}"
  "${HF_HOME:-}"
  "/runpod-volume/huggingface-cache/hub"
  "/runpod-volume/huggingface-cache"
  "/root/.cache/huggingface/hub"
  "/workspace/.cache/huggingface/hub"
)

LLAMA_CACHED_MODEL="${LLAMA_CACHED_MODEL//\//--}"
MODEL_REL="${LLAMA_CACHED_GGUF_PATH}"

echo "LLAMA_CACHED_MODEL=$LLAMA_CACHED_MODEL"
echo "LLAMA_CACHED_GGUF_PATH=$LLAMA_CACHED_GGUF_PATH"
echo "CACHE_DIR=${CACHE_DIR:-}"
echo "HF_HOME=${HF_HOME:-}"
echo "HUGGINGFACE_HUB_CACHE=${HUGGINGFACE_HUB_CACHE:-}"

if [[ -z "$LLAMA_CACHED_MODEL" ]]; then
  echo "image ready, model not found (LLAMA_CACHED_MODEL is empty)"
  exit 1
fi

trap cleanup SIGINT SIGTERM

echo "start.sh: Stopping existing llama-server instances (if any)..."
{
    pkill llama-server 2>/dev/null
} || {
    echo "start.sh: No llama-server running"
}

MODEL_PATH=""

for d in "${PROBE_DIRS[@]}"; do
  [[ -n "$d" ]] || continue

  echo "=== probing: $d ==="
  ls -la "$d" 2>/dev/null | head -n 60 || { echo "(missing)"; continue; }

  SNAP_DIR="$d/models--${LLAMA_CACHED_MODEL}/snapshots"
  if [[ -d "$SNAP_DIR" ]]; then
    echo "found snapshots dir: $SNAP_DIR"
    ls -la "$SNAP_DIR" 2>/dev/null | head -n 60 || true

    # Pick newest snapshot (sorted) and see if GGUF exists
    SNAP_ID="$(ls -1 "$SNAP_DIR" 2>/dev/null | sort | tail -n 1 || true)"
    if [[ -n "$SNAP_ID" ]]; then
      CAND="$SNAP_DIR/$SNAP_ID/$MODEL_REL"
      echo "candidate: $CAND"
      if [[ -f "$CAND" ]]; then
        MODEL_PATH="$CAND"
        break
      fi
      echo "candidate not found; listing snapshot root:"
      ls -la "$SNAP_DIR/$SNAP_ID" 2>/dev/null | head -n 100 || true
    fi
  else
    echo "no snapshots dir at: $SNAP_DIR"
  fi
done

if [[ -z "$MODEL_PATH" ]]; then
  echo "image ready, model not found"
  exit 1
fi

echo "model found at: $MODEL_PATH"

# -------- build llama-server args --------
LLAMA_SERVER_BIN="${LLAMA_SERVER_BIN:-/app/llama-server}"
LLAMA_SERVER_HOST="${LLAMA_SERVER_HOST:-0.0.0.0}"

# If you already pass args via LLAMA_SERVER_CMD_ARGS, keep them.
# If you don't, these defaults are sane for RunPod.
LLAMA_SERVER_CMD_ARGS="${LLAMA_SERVER_CMD_ARGS:---ctx-size 8192 -ngl 999 -n 160}"

echo "starting: $LLAMA_SERVER_BIN -m \"$MODEL_PATH\" $LLAMA_SERVER_CMD_ARGS"
touch llama.server.log

LD_LIBRARY_PATH=/app "$LLAMA_SERVER_BIN" -m "$MODEL_PATH" --port 3098 $LLAMA_SERVER_CMD_ARGS 2>&1 | tee llama.server.log &

LLAMA_SERVER_PID=$! # store the process ID (PID) of the background command

tries_so_far=0

check_server_is_running() {
    echo "start.sh: Checking if llama-server is done initializing..."

    if grep -q "listening" llama.server.log; then
        return 0
    fi

    tries_so_far=$((tries_so_far + 1))

    if [ $tries_so_far -ge 120 ]; then
        echo "start.sh: Error: llama-server did not start within 60 seconds."
        exit 1
    fi

    if ! kill -0 $LLAMA_SERVER_PID 2>/dev/null; then
        echo "start.sh: Error: llama-server process has exited unexpectedly."
        exit 1
    fi

    return 1
}

echo "start.sh: Waiting for llama-server to start..."

# wait for the server to start
while ! check_server_is_running; do
    # we don't want to lose too much time, so we check very frequently
    sleep 0.5
done

echo "start.sh: llama-server is up and running, delegating to the handler script."

python -u handler.py "${1:-}"
