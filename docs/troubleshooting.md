# Troubleshooting

This document collects the most likely problems when running the JPEG AI reference software under WSL2.

## `nvidia-smi` does not work inside WSL

The installer does not install Windows NVIDIA drivers. Under WSL2, GPU access is provided through the Windows NVIDIA driver and exposed into the Linux distribution.

Check first from Windows PowerShell:

```powershell
wsl -l -v
```

The distribution must run as WSL version 2.

Then check inside WSL:

```bash
nvidia-smi
```

If this fails, fix the Windows NVIDIA driver and WSL2 GPU layer before debugging JPEG AI itself.

## Conda environment is not created

Recent Conda versions may require accepting the Terms of Service for default channels. The installer tries to run:

```bash
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
```

If environment creation fails, run these commands manually and then retry:

```bash
cd ~/jpeg-ai-reference-software
make setup_env
```

## `libtorch_cpu.so: cannot enable executable stack`

Some WSL setups can fail when importing PyTorch with an error similar to:

```text
ImportError: libtorch_cpu.so: cannot enable executable stack as shared object requires
```

The installer tries to fix this automatically by locating `libtorch_cpu.so`, backing it up, and running:

```bash
patchelf --clear-execstack path/to/libtorch_cpu.so
```

If you need to do it manually, locate the file first:

```bash
find ~/miniconda3/envs/jpeg_ai_vm -path '*/torch/lib/libtorch_cpu.so' -type f
```

Then back it up and patch it:

```bash
cp PATH_TO_LIBTORCH_CPU_SO PATH_TO_LIBTORCH_CPU_SO.bak
patchelf --clear-execstack PATH_TO_LIBTORCH_CPU_SO
```

After recreating the `jpeg_ai_vm` environment, this workaround may need to be repeated.

## The encoder does not accept JPG input

The reference encoder workflow expects PNG input. Use `scripts/jpg2jai_35.sh`, which converts the source image to a PNG raster before JPEG AI encoding.

This means the workflow is not direct bitstream recompression from JPEG to JPEG AI. It is a raster-based encode workflow.

## The `.jai` file is not always smaller than the source JPEG

This can happen, especially with already well-compressed mobile JPEG files. The wrapper script uses a 35 percent size budget to keep tests practically meaningful, but that budget is only a policy choice, not a guarantee of perceptual superiority.

## `make setup_env` fails on a new Debian version

The upstream reference software may expect a package set closer to Ubuntu 18.04+ or specific CUDA-era dependencies. This repository deliberately installs common build dependencies manually before running `make setup_env`, but upstream scripts can still change.

The most useful first checks are:

```bash
cd ~/jpeg-ai-reference-software
git status
git pull --ff-only
make setup_env
```

If the failure is caused by a missing Debian package, install it explicitly with `apt` and rerun `make setup_env`.
