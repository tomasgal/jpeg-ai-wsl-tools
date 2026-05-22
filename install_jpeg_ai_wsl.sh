#!/usr/bin/env bash
set -euo pipefail

# JPEG AI WSL installer
# Target: Windows 11 + WSL2 + Debian or Ubuntu + NVIDIA GPU
#
# This script installs system dependencies, Miniconda if missing, clones the
# official JPEG AI reference software, creates the jpeg_ai_vm Conda environment,
# builds the reference software dependencies, and checks PyTorch/CUDA visibility.
#
# It intentionally does not install NVIDIA drivers. Under WSL, CUDA access is
# provided through the Windows NVIDIA driver. Check `nvidia-smi` inside WSL first.

REPO_URL="https://gitlab.com/wg1/jpeg-ai/jpeg-ai-reference-software.git"
JPEG_AI_DIR="$HOME/jpeg-ai-reference-software"
MINICONDA_DIR="$HOME/miniconda3"
MINICONDA_INSTALLER="$HOME/miniconda.sh"
ENV_NAME="jpeg_ai_vm"

log() {
    echo
    echo "==> $*"
}

warn() {
    echo
    echo "WARNING: $*" >&2
}

require_linux() {
    if [[ "$(uname -s)" != "Linux" ]]; then
        echo "This installer must be run inside Linux, preferably Debian or Ubuntu under WSL2." >&2
        exit 1
    fi
}

install_system_packages() {
    log "Installing system packages"

    if ! command -v apt >/dev/null 2>&1; then
        echo "This installer currently expects an apt-based distribution such as Debian or Ubuntu." >&2
        exit 1
    fi

    sudo apt update
    sudo apt install -y \
        git git-lfs build-essential cmake curl wget ca-certificates pkg-config \
        doxygen graphviz python3-dev patchelf

    git lfs install
}

check_gpu() {
    log "Checking NVIDIA GPU visibility inside WSL"

    if command -v nvidia-smi >/dev/null 2>&1; then
        nvidia-smi || warn "nvidia-smi exists but returned an error. CUDA may not be usable."
    else
        warn "nvidia-smi was not found inside WSL. The install can continue, but GPU acceleration may not work."
    fi
}

install_miniconda_if_missing() {
    if [[ -x "$MINICONDA_DIR/bin/conda" ]]; then
        log "Miniconda already found at $MINICONDA_DIR"
        return
    fi

    log "Installing Miniconda"
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O "$MINICONDA_INSTALLER"
    bash "$MINICONDA_INSTALLER" -b -p "$MINICONDA_DIR"

    "$MINICONDA_DIR/bin/conda" init bash || true
}

prepare_conda() {
    # Make conda available in this non-interactive shell.
    # shellcheck disable=SC1091
    source "$MINICONDA_DIR/etc/profile.d/conda.sh"

    log "Accepting default Anaconda channel Terms of Service when supported"
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
    conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true
}

clone_or_update_reference_software() {
    if [[ -d "$JPEG_AI_DIR/.git" ]]; then
        log "JPEG AI reference repository already exists. Pulling latest changes."
        git -C "$JPEG_AI_DIR" pull --ff-only || warn "Could not fast-forward the existing JPEG AI repository. Continuing with current checkout."
    else
        log "Cloning official JPEG AI reference software"
        git clone "$REPO_URL" "$JPEG_AI_DIR"
    fi
}

build_reference_environment() {
    log "Creating Conda environment and building JPEG AI reference dependencies"
    cd "$JPEG_AI_DIR"
    make setup_env
}

find_libtorch_cpu() {
    find "$MINICONDA_DIR/envs/$ENV_NAME" -path '*/torch/lib/libtorch_cpu.so' -type f 2>/dev/null | head -n 1
}

check_python_stack() {
    log "Checking PyTorch, pybind11, and CUDA visibility"

    conda activate "$ENV_NAME"

    if python -c "import torch, pybind11; print('torch', torch.__version__); print('cuda', torch.cuda.is_available()); print('pybind11', pybind11.__version__)"; then
        return
    fi

    warn "PyTorch import failed. Trying the common WSL executable-stack workaround for libtorch_cpu.so."

    local libtorch_path
    libtorch_path="$(find_libtorch_cpu || true)"

    if [[ -z "$libtorch_path" ]]; then
        echo "Could not locate libtorch_cpu.so inside $MINICONDA_DIR/envs/$ENV_NAME" >&2
        exit 1
    fi

    cp "$libtorch_path" "${libtorch_path}.bak"
    patchelf --clear-execstack "$libtorch_path"

    python -c "import torch, pybind11; print('torch', torch.__version__); print('cuda', torch.cuda.is_available()); print('pybind11', pybind11.__version__)"
}

main() {
    require_linux
    check_gpu
    install_system_packages
    install_miniconda_if_missing
    prepare_conda
    clone_or_update_reference_software
    build_reference_environment
    check_python_stack

    log "Installation finished"
    echo "JPEG AI reference software directory: $JPEG_AI_DIR"
    echo "To activate the environment later, run:"
    echo "  source $MINICONDA_DIR/etc/profile.d/conda.sh && conda activate $ENV_NAME"
    echo "Next recommended test:"
    echo "  bash $(pwd)/../jpeg-ai-wsl-tools/scripts/smoke_test.sh"
}

main "$@"
