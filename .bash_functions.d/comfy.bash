# Source from ~/.bash_functions; Bash functions require Bash.
# ComfyUI systemd service management.
comfy() {
    local action="start"
    local service="comfyui.service"

    case "${1:-}" in
        -r|--restart)
            action="restart"
            ;;
        -s|--stop)
            action="stop"
            ;;
        "")
            action="start"
            ;;
        -h|--help)
            cat <<'EOF'
Usage: comfy [option]

  (none)          Start ComfyUI
  -r, --restart   Restart ComfyUI
  -s, --stop      Stop ComfyUI
  -h, --help      Show this help

The service URL and status are shown after the action.
EOF
            return 0
            ;;
        *)
            printf "Unknown option: %s\n" "$1" >&2
            echo "Use 'comfy --help' for usage." >&2
            return 1
            ;;
    esac

    if ! systemctl cat "$service" &>/dev/null; then
        printf "Error: systemd service '%s' was not found.\n" "$service" >&2
        return 1
    fi

    case "$action" in
        start)
            if systemctl is-active --quiet "$service"; then
                echo "ComfyUI is already running."
            else
                echo "Starting ComfyUI service..."
                systemctl start "$service" || return 1
            fi
            ;;

        restart)
            echo "Restarting ComfyUI service..."
            systemctl restart "$service" || return 1
            ;;

        stop)
            echo "Stopping ComfyUI service..."
            systemctl stop "$service" || return 1
            ;;
    esac

    if systemctl is-active --quiet "$service"; then
        local comfyPort
        local comfyURL

        comfyPort=$(
            systemctl cat "$service" |
                grep -oP '(?<=--port )\d+' |
                head -n 1
        )
        comfyPort=${comfyPort:-8188}
        comfyURL="http://localhost:$comfyPort"

        echo
        echo "ComfyUI: $comfyURL"

        # If we started/restarted ComfyUI, wait for the web server
        # to become available before opening the browser.
        if [[ "$action" == "start" || "$action" == "restart" ]]; then
            printf "Waiting for ComfyUI"

            for _ in {1..30}; do
                if curl --silent --fail --output /dev/null \
                    "$comfyURL/system_stats"; then
                    echo
                    echo "Opening ComfyUI..."
                    xdg-open "$comfyURL" >/dev/null 2>&1 &
                    disown
                    break
                fi

                printf "."
                sleep 1
            done

            echo
        fi
    fi

    echo
    systemctl status "$service" --no-pager
}

# Comfyui backup solution - made with ChatGPT
comfy-backup() {
    # ============================================================
    # ComfyUI Rebuild Backup
    #
    # Backs up the parts of ComfyUI needed to rebuild the setup
    # while deliberately excluding:
    #   - venv
    #   - models
    #   - output
    #   - input
    #   - temp/cache data
    #
    # Backup location:
    #   /mnt/storage/comfyui-backups/
    # ============================================================

    local COMFY="/mnt/comfyui"
    local STORAGE="/mnt/storage/comfyui-backups"
    local STAGE="$STORAGE/.comfyui-backup-stage"
    local ARCHIVE="$STORAGE/comfyui-backup.tar.zst"
    local TIMESTAMP
    local VENV="$COMFY/venv3.10"

    TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

    echo
    echo "=============================================="
    echo "        ComfyUI Rebuild Backup"
    echo "=============================================="
    echo
    echo "ComfyUI : $COMFY"
    echo "Storage : $STORAGE"
    echo

    # ------------------------------------------------------------
    # Sanity checks
    # ------------------------------------------------------------

    if [[ ! -d "$COMFY" ]]; then
        echo "ERROR: ComfyUI directory not found:"
        echo "       $COMFY"
        return 1
    fi

    if [[ ! -d "/mnt/storage" ]]; then
        echo "ERROR: /mnt/storage does not exist."
        return 1
    fi

    if ! command -v zstd >/dev/null 2>&1; then
        echo "ERROR: zstd is not installed."
        echo "Install it with:"
        echo "  sudo apt install zstd"
        return 1
    fi

    mkdir -p "$STORAGE"

    # ------------------------------------------------------------
    # Clean previous staging area
    # ------------------------------------------------------------

    rm -rf "$STAGE"
    mkdir -p "$STAGE"

    # ------------------------------------------------------------
    # Create backup directory structure
    # ------------------------------------------------------------

    mkdir -p \
        "$STAGE/comfyui" \
        "$STAGE/environment" \
        "$STAGE/systemd" \
        "$STAGE/models"

    # ------------------------------------------------------------
    # Copy ComfyUI configuration / application data
    #
    # We use rsync exclusions rather than manually guessing every
    # ComfyUI file that may become important in the future.
    # ------------------------------------------------------------

    echo "[1/8] Backing up ComfyUI configuration and application data..."

    rsync -a \
        --exclude='venv/' \
        --exclude='venv3.10/' \
        --exclude='venv3.11/' \
        --exclude='venv3.13/' \
        --exclude='venv313/' \
        --exclude='models/' \
        --exclude='output/' \
        --exclude='input/' \
        --exclude='temp/' \
        --exclude='cache/' \
        --exclude='__pycache__/' \
        --exclude='*.pyc' \
        "$COMFY/" \
        "$STAGE/comfyui/"

    # ------------------------------------------------------------
    # Remove anything huge/unnecessary that may have slipped in
    # ------------------------------------------------------------

    rm -rf \
        "$STAGE/comfyui/venv" \
        "$STAGE/comfyui/venv3.10" \
        "$STAGE/comfyui/venv3.11" \
        "$STAGE/comfyui/venv3.13" \
        "$STAGE/comfyui/venv313" \
        "$STAGE/comfyui/models" \
        "$STAGE/comfyui/output" \
        "$STAGE/comfyui/input" \
        "$STAGE/comfyui/temp"

    # ------------------------------------------------------------
    # Environment information
    # ------------------------------------------------------------

    echo "[2/8] Recording Python / Torch / ROCm environment..."

    {
        echo "============================================================"
        echo "ComfyUI Environment Snapshot"
        echo "Created: $(date --iso-8601=seconds)"
        echo "============================================================"
        echo
        echo "ComfyUI:"
        echo "  Path: $COMFY"
        if [[ -d "$COMFY/.git" ]]; then
            echo "  Git branch: $(git -C "$COMFY" branch --show-current 2>/dev/null)"
            echo "  Git commit: $(git -C "$COMFY" rev-parse HEAD 2>/dev/null)"
            echo "  Git remote: $(git -C "$COMFY" remote get-url origin 2>/dev/null)"
        fi
        echo
        echo "Python:"
        if [[ -x "$VENV/bin/python" ]]; then
            "$VENV/bin/python" --version
            echo "  Executable: $VENV/bin/python"
        else
            python3 --version
            echo "  WARNING: $VENV/bin/python not found"
        fi
        echo
        echo "System:"
        uname -a
        echo
        echo "OS:"
        cat /etc/os-release 2>/dev/null
        echo
    } > "$STAGE/environment/SYSTEM_INFO.txt"

    # ------------------------------------------------------------
    # Python package list
    # ------------------------------------------------------------

    if [[ -x "$VENV/bin/pip" ]]; then
        "$VENV/bin/pip" freeze \
            > "$STAGE/environment/pip-freeze.txt" 2>/dev/null

        "$VENV/bin/pip" list --format=freeze \
            > "$STAGE/environment/pip-list.txt" 2>/dev/null

        "$VENV/bin/python" - <<'PY' \
            > "$STAGE/environment/PYTORCH_ROCM_INFO.txt" 2>&1
import sys

print("Python:", sys.version)

try:
    import torch

    print("Torch:", torch.__version__)
    print("Torch HIP:", torch.version.hip)
    print("CUDA available:", torch.cuda.is_available())

    if torch.cuda.is_available():
        print("GPU:", torch.cuda.get_device_name(0))
        print("GPU capability:", torch.cuda.get_device_capability(0))
        print("Device count:", torch.cuda.device_count())

except Exception as e:
    print("Torch inspection failed:", repr(e))
PY
    fi

    # ------------------------------------------------------------
    # Environment variables relevant to ComfyUI / ROCm
    # ------------------------------------------------------------

    echo "[3/8] Recording ComfyUI environment variables..."

    env | sort | grep -E \
        '^(HSA_|HIP_|ROCM_|TORCH_|PYTORCH_|CUDA_|COMFY_|PYTHON|PATH=)' \
        > "$STAGE/environment/ENVIRONMENT_VARIABLES.txt" 2>/dev/null || true

    # ------------------------------------------------------------
    # Custom node git information
    # ------------------------------------------------------------

    echo "[4/8] Recording custom-node repositories..."

    {
        echo "============================================================"
        echo "Custom Node Git Repositories"
        echo "============================================================"
        echo

        if [[ -d "$COMFY/custom_nodes" ]]; then
            find "$COMFY/custom_nodes" -mindepth 1 -maxdepth 1 -type d \
                | sort \
                | while read -r NODE; do

                    echo "------------------------------------------------------------"
                    echo "Node: $(basename "$NODE")"

                    if [[ -d "$NODE/.git" ]]; then
                        echo "Git: YES"
                        echo "Remote:"
                        git -C "$NODE" remote -v 2>/dev/null | head -2
                        echo "Branch:"
                        git -C "$NODE" branch --show-current 2>/dev/null
                        echo "Commit:"
                        git -C "$NODE" rev-parse HEAD 2>/dev/null
                    else
                        echo "Git: NO"
                    fi

                    echo
                done
        fi
    } > "$STAGE/environment/CUSTOM_NODE_GIT.txt"

    # ------------------------------------------------------------
    # Systemd service
    # ------------------------------------------------------------

    echo "[5/8] Backing up ComfyUI systemd service..."

    if [[ -f /etc/systemd/system/comfyui.service ]]; then
        cp \
            /etc/systemd/system/comfyui.service \
            "$STAGE/systemd/comfyui.service"

        systemctl cat comfyui.service \
            > "$STAGE/systemd/comfyui.service.full.txt" 2>/dev/null || true

        systemctl show comfyui.service \
            > "$STAGE/systemd/comfyui.service.properties.txt" 2>/dev/null || true
    else
        echo "No /etc/systemd/system/comfyui.service found." \
            > "$STAGE/systemd/README.txt"
    fi

    # ------------------------------------------------------------
    # Model manifest
    #
    # We don't copy models. We record their paths, sizes and hashes.
    # ------------------------------------------------------------

    echo "[6/8] Building model manifest..."

    if [[ -d "$COMFY/models" ]]; then

        find "$COMFY/models" -type f \
            -printf '%P\t%s\t%TY-%Tm-%Td %TH:%TM:%TS\n' \
            | sort \
            > "$STAGE/models/MODEL_MANIFEST.txt"

        echo "Generating SHA256 checksums for models..."
        echo "This can take a while with a large model collection."
        echo

        (
            cd "$COMFY/models" || exit 1
            find . -type f -print0 \
                | sort -z \
                | xargs -0 sha256sum
        ) > "$STAGE/models/MODEL_SHA256SUMS.txt"

    else
        echo "Models directory not found: $COMFY/models" \
            > "$STAGE/models/MODEL_MANIFEST.txt"
    fi

    # ------------------------------------------------------------
    # Model URL list
    #
    # This file intentionally isn't auto-generated because local
    # model files normally don't contain their original download URL.
    # ------------------------------------------------------------

    if [[ ! -f "$STAGE/models/MODEL_URLS.txt" ]]; then
        cat > "$STAGE/models/MODEL_URLS.txt" <<'EOF'
# ============================================================
# ComfyUI Model Download URLs
#
# Add the original download URL for models you want to be able
# to automatically restore.
#
# Format:
#
# relative/path/to/model.safetensors<TAB>URL
#
# Examples:
#
# checkpoints/foo.safetensors    https://...
# loras/bar.safetensors          https://...
#
# This file is intentionally maintained separately from the
# automatically generated MODEL_MANIFEST.txt.
# ============================================================

EOF
    fi

    # ------------------------------------------------------------
    # Disk usage report
    # ------------------------------------------------------------

    echo "[7/8] Recording backup statistics..."

    {
        echo "============================================================"
        echo "ComfyUI Backup Statistics"
        echo "============================================================"
        echo
        echo "Generated: $(date --iso-8601=seconds)"
        echo
        echo "ComfyUI disk usage:"
        du -sh "$COMFY" 2>/dev/null
        echo
        echo "Models disk usage:"
        du -sh "$COMFY/models" 2>/dev/null
        echo
        echo "Custom nodes:"
        find "$COMFY/custom_nodes" -mindepth 1 -maxdepth 1 -type d \
            2>/dev/null | wc -l
        echo
        echo "Workflows:"
        find "$COMFY" -type f \
            \( -iname '*.json' -o -iname '*.yaml' -o -iname '*.yml' \) \
            2>/dev/null | wc -l
        echo
    } > "$STAGE/environment/BACKUP_STATISTICS.txt"

    # ------------------------------------------------------------
    # Include shell functions
    # ------------------------------------------------------------

    if [[ -f "$HOME/.bash_functions" ]]; then
        mkdir -p "$STAGE/shell"
        cp "$HOME/.bash_functions" \
            "$STAGE/shell/bash_functions"
    fi
    if [[ -d "$HOME/.bash_functions.d" ]]; then
        mkdir -p "$STAGE/shell/bash_functions.d"
        cp -a "$HOME/.bash_functions.d/." "$STAGE/shell/bash_functions.d/"
    fi

    # ------------------------------------------------------------
    # Create restore helper
    # ------------------------------------------------------------

    cat > "$STAGE/RESTORE_README.txt" <<'EOF'
============================================================
ComfyUI Rebuild Backup
============================================================

This archive contains the configuration and custom setup
required to rebuild the ComfyUI installation.

It intentionally DOES NOT contain:

  - Python virtual environment
  - ComfyUI models
  - output images
  - input images
  - temporary files
  - caches

Contents:

  comfyui/
      ComfyUI application
      custom_nodes/
      user/
      workflows/
      configuration files
      other application data

  environment/
      pip-freeze.txt
      pip-list.txt
      SYSTEM_INFO.txt
      PYTORCH_ROCM_INFO.txt
      ENVIRONMENT_VARIABLES.txt
      CUSTOM_NODE_GIT.txt
      BACKUP_STATISTICS.txt

  models/
      MODEL_MANIFEST.txt
      MODEL_SHA256SUMS.txt
      MODEL_URLS.txt

  systemd/
      comfyui.service
      systemd service information

  shell/
      bash_functions

============================================================
BASIC RESTORE
============================================================

1. Install the required OS packages.

2. Clone/install ComfyUI into:

      /mnt/comfyui

3. Restore the contents of comfyui/ into /mnt/comfyui/.

4. Recreate the Python virtual environment using the Python
   version recorded in:

      environment/SYSTEM_INFO.txt

5. Install Python dependencies:

      pip install -r environment/pip-freeze.txt

6. Restore/install the models listed in:

      models/MODEL_MANIFEST.txt

   using URLs from:

      models/MODEL_URLS.txt

7. Restore the systemd service:

      sudo cp systemd/comfyui.service \
          /etc/systemd/system/comfyui.service

      sudo systemctl daemon-reload

8. Start ComfyUI.

============================================================
IMPORTANT
============================================================

The MODEL_SHA256SUMS.txt file can be used to verify that
restored model files are identical to the originals.

Custom nodes are backed up including their .git directories
when they are git repositories. Their original remotes,
branches and commits are recorded in:

      environment/CUSTOM_NODE_GIT.txt

============================================================
EOF

    # ------------------------------------------------------------
    # Create archive
    # ------------------------------------------------------------

    echo "[8/8] Creating compressed backup archive..."
    echo

    rm -f "$ARCHIVE"

    tar \
        --zstd \
        -cf "$ARCHIVE" \
        -C "$STAGE" \
        .

    # ------------------------------------------------------------
    # Cleanup
    # ------------------------------------------------------------

    rm -rf "$STAGE"

    # ------------------------------------------------------------
    # Final report
    # ------------------------------------------------------------

    echo
    echo "=============================================="
    echo "        BACKUP COMPLETE"
    echo "=============================================="
    echo
    echo "Archive:"
    echo "  $ARCHIVE"
    echo
    echo "Size:"
    du -h "$ARCHIVE"
    echo
    echo "Created:"
    date
    echo
    echo "Model manifest:"
    echo "  models/MODEL_MANIFEST.txt"
    echo
    echo "Model URLs:"
    echo "  models/MODEL_URLS.txt"
    echo
    echo "Environment:"
    echo "  environment/pip-freeze.txt"
    echo "  environment/PYTORCH_ROCM_INFO.txt"
    echo "  environment/SYSTEM_INFO.txt"
    echo
    echo "To inspect the archive:"
    echo "  tar --zstd -tf \"$ARCHIVE\" | less"
    echo
}
