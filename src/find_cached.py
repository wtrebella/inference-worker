import os
import argparse
import sys

# Standard RunPod volume path for HF cache
CACHE_DIR = "/runpod-volume/huggingface-cache/hub"

def find_model_path(model_name, gguf_file):
    """
    Tries to locate the GGUF file in two ways:
    1. Direct download location (flat directory)
    2. Hugging Face Hub snapshot structure
    """

    # Check 1: Direct file in the Hub folder (from your curl download in start.sh)
    # This matches: /runpod-volume/huggingface-cache/hub/filename.gguf
    direct_path = os.path.join(CACHE_DIR, gguf_file)
    if os.path.isfile(direct_path):
        return direct_path

    # Check 2: The official Hugging Face Hub structure
    # This matches: /runpod-volume/huggingface-cache/hub/models--Org--Model/snapshots/hash/filename.gguf
    cache_name = model_name.replace("/", "--")
    snapshots_dir = os.path.join(CACHE_DIR, f"models--{cache_name}", "snapshots")

    if os.path.exists(snapshots_dir):
        # Get all snapshot folders (hashes) and sort by modification time (newest first)
        snapshots = sorted(
            [os.path.join(snapshots_dir, d) for d in os.listdir(snapshots_dir)],
            key=os.path.getmtime,
            reverse=True
        )

        for snap_path in snapshots:
            full_path = os.path.join(snap_path, gguf_file)
            if os.path.isfile(full_path):
                return full_path

    return None

def main():
    parser = argparse.ArgumentParser(
        description="Find the full GGUF path from the Hugging Face cache."
    )
    parser.add_argument("model", type=str, help="The model name (e.g., bartowski/qwen2.5-72b-instruct-GGUF)")
    parser.add_argument("path", type=str, help="The GGUF filename (e.g., Qwen2.5-72B-Instruct-Q3_K_L.gguf)")

    args = parser.parse_args()

    # Important: In your start.sh, you call this as:
    # python ./find_cached.py $LLAMA_CACHED_MODEL $LLAMA_CACHED_GGUF_PATH

    result_path = find_model_path(args.model, args.path)

    if result_path:
        # Print only the path so the shell script can capture it in a variable
        print(result_path, end="")
    else:
        # Exit with an error code so start.sh knows the model is missing
        sys.exit(1)

if __name__ == "__main__":
    main()
