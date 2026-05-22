# How to run JPEG AI today: Windows 11, WSL2, and NVIDIA GPU

The theory around JPEG AI is fascinating, but sooner or later a more prosaic question appears: can this already be run on an ordinary workstation, or is it still only standardization folklore? The short answer is: yes, it can be run, but it should not be mistaken for a polished consumer product. JPEG AI currently does not behave like a simple `apt install jpeg-ai` package. In practice, one works with the official reference software, command-line tools, Miniconda, and a little patience.

The workflow in this repository was prepared for Windows 11, WSL2, Debian or Ubuntu, and an NVIDIA GPU visible inside WSL. It is not tied to one exact GPU model. The important condition is that `nvidia-smi` works inside WSL, because CUDA access in this setup is provided through the Windows NVIDIA driver.

The installer performs the practical bootstrap steps: it installs common Debian/Ubuntu build dependencies, installs Miniconda if it is not already present, clones the official JPEG AI reference software, runs `make setup_env`, and checks whether PyTorch can see CUDA. It also attempts to handle a common WSL/PyTorch issue around `libtorch_cpu.so` requiring an executable stack.

A minimal sanity check is provided by `scripts/smoke_test.sh`. It creates a tiny synthetic PNG, encodes it to `.jai`, and decodes it back to PNG. This is not a quality benchmark; it is only a way to confirm that the encoder and decoder can actually run.

The more practical script is `scripts/jpg2jai_35.sh`. Because the reference encoder expects PNG input, the script first converts a JPEG-like input into a PNG raster. It then tries several target BPP settings, selecting the highest one that still produces a `.jai` file no larger than 35 percent of the original input file. Finally, it decodes the `.jai` file back to PNG and creates a high-quality reconstructed JPEG for ordinary viewing.

This distinction matters. The workflow does not directly recompress a JPEG bitstream into JPEG AI. It moves through a raster representation. That is technically correct for the current reference workflow, but it also means that comparisons against optimized mobile JPEG files should be interpreted carefully. The goal is not to prove that JPEG AI always wins in every practical case today. The goal is to make the reference implementation usable enough for experimentation, testing, and further research.

In that sense, JPEG AI is already real software, but not yet invisible infrastructure. It still looks like a technology in transition: standardized enough to study seriously, but raw enough that installation remains part of the experiment.
