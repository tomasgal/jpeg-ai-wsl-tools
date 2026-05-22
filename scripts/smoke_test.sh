#!/usr/bin/env bash
set -euo pipefail

# Minimal JPEG AI smoke test.
#
# It creates a small synthetic PNG, encodes it to .jai, and decodes it back to PNG.
# This is not a quality benchmark. It only verifies that the reference encoder and
# decoder can run in the current environment.

JPEG_AI_DIR="${JPEG_AI_DIR:-$HOME/jpeg-ai-reference-software}"
ENV_NAME="${ENV_NAME:-jpeg_ai_vm}"
MINICONDA_DIR="${MINICONDA_DIR:-$HOME/miniconda3}"

if [[ ! -d "$JPEG_AI_DIR" ]]; then
    echo "JPEG AI reference directory not found: $JPEG_AI_DIR" >&2
    echo "Run ./install_jpeg_ai_wsl.sh first." >&2
    exit 1
fi

if [[ ! -f "$MINICONDA_DIR/etc/profile.d/conda.sh" ]]; then
    echo "Conda profile script not found: $MINICONDA_DIR/etc/profile.d/conda.sh" >&2
    exit 1
fi

# shellcheck disable=SC1091
source "$MINICONDA_DIR/etc/profile.d/conda.sh"
conda activate "$ENV_NAME"

cd "$JPEG_AI_DIR"

python - <<'PY'
from PIL import Image

img = Image.new("RGB", (64, 64))
for y in range(64):
    for x in range(64):
        img.putpixel((x, y), ((x * 4) % 256, (y * 4) % 256, ((x + y) * 2) % 256))

img.save("test_64.png")
print("created test_64.png")
PY

python -m src.reco.coders.encoder test_64.png test_64.jai --cfg cfg/tools_off.json cfg/profiles/simple.json
python -m src.reco.coders.decoder test_64.jai test_64_decoded.png

echo
echo "Smoke test finished. Created:"
ls -lh test_64.png test_64.jai test_64_decoded.png
