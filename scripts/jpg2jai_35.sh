#!/usr/bin/env bash
set -euo pipefail

# Convert a JPEG or another image format to JPEG AI using the official reference
# encoder workflow.
#
# The reference encoder expects PNG input. This script therefore:
# 1. reads the input image,
# 2. converts it to a PNG raster,
# 3. tries several target BPP settings,
# 4. chooses the highest setting whose .jai file fits within 35 percent of the
#    original input file size,
# 5. decodes the .jai file back to PNG,
# 6. creates a distribution-friendly reconstructed JPEG.
#
# Usage:
#   ./jpg2jai_35.sh 001.jpg

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <input_image>" >&2
    exit 1
fi

INPUT="$1"

JPEG_AI_DIR="${JPEG_AI_DIR:-$HOME/jpeg-ai-reference-software}"
ENV_NAME="${ENV_NAME:-jpeg_ai_vm}"
MINICONDA_DIR="${MINICONDA_DIR:-$HOME/miniconda3}"
OUT_DIR="$JPEG_AI_DIR/out"
TMP_DIR="$OUT_DIR/.tmp_35"

mkdir -p "$OUT_DIR" "$TMP_DIR"

if [[ ! -f "$INPUT" ]]; then
    echo "Input file does not exist: $INPUT" >&2
    exit 1
fi

if [[ ! -d "$JPEG_AI_DIR" ]]; then
    echo "JPEG AI reference directory not found: $JPEG_AI_DIR" >&2
    echo "Run install_jpeg_ai_wsl.sh first." >&2
    exit 1
fi

if [[ ! -f "$MINICONDA_DIR/etc/profile.d/conda.sh" ]]; then
    echo "Conda profile script not found: $MINICONDA_DIR/etc/profile.d/conda.sh" >&2
    exit 1
fi

# shellcheck disable=SC1091
source "$MINICONDA_DIR/etc/profile.d/conda.sh"
conda activate "$ENV_NAME"

BASENAME="$(basename "$INPUT")"
NAME="${BASENAME%.*}"

SRC_SIZE=$(stat -c%s "$INPUT")
TARGET_SIZE=$(python - "$SRC_SIZE" <<'PY'
import sys
src = int(sys.argv[1])
print(max(1, int(src * 0.35)))
PY
)

# Candidate values are tried from higher quality to lower quality.
# The first one that fits the size budget is selected.
CANDIDATES=(100 85 70 55 40 30 20 15 10)
PROFILE="high"
INPUT_PNG="$OUT_DIR/${NAME}_input.png"

python - "$INPUT" "$INPUT_PNG" <<'PY'
from PIL import Image
import sys

src = sys.argv[1]
dst = sys.argv[2]

im = Image.open(src).convert("RGB")
dpi = im.info.get("dpi", (96, 96))
im.save(dst, dpi=dpi)
print(f"Prepared PNG: {dst}, size={im.size}, dpi={dpi}")
PY

BEST_BPP=""
BEST_JAI=""
BEST_SIZE=0

cd "$JPEG_AI_DIR"

echo "Source: $INPUT"
echo "Source size: $SRC_SIZE B"
echo "Target JAI max size, 35 percent: $TARGET_SIZE B"
echo "Profile: $PROFILE"
echo

for BPP in "${CANDIDATES[@]}"; do
    TEST_JAI="$TMP_DIR/${NAME}_high_bpp${BPP}.jai"
    rm -f "$TEST_JAI"

    echo "Trying BPP x100 = $BPP ..."
    python -m src.reco.coders.encoder \
        "$INPUT_PNG" \
        "$TEST_JAI" \
        --set_target_bpp "$BPP" \
        --cfg cfg/tools_on.json "cfg/profiles/${PROFILE}.json" >/dev/null

    JAI_SIZE=$(stat -c%s "$TEST_JAI")
    echo "  JAI size: $JAI_SIZE B"

    if [[ "$JAI_SIZE" -le "$TARGET_SIZE" ]]; then
        BEST_BPP="$BPP"
        BEST_JAI="$TEST_JAI"
        BEST_SIZE="$JAI_SIZE"
        echo "  -> fits the limit"
        break
    else
        echo "  -> does not fit the limit"
    fi
done

if [[ -z "$BEST_BPP" ]]; then
    echo
    echo "No candidate setting fit the 35 percent limit." >&2
    echo "Try adding lower BPP candidates or use a less strict budget." >&2
    exit 2
fi

FINAL_JAI="$OUT_DIR/${NAME}_ratio0_35_bpp${BEST_BPP}.jai"
FINAL_PNG="$OUT_DIR/${NAME}_ratio0_35_bpp${BEST_BPP}_reconstructed.png"
FINAL_JPG="$OUT_DIR/${NAME}_ratio0_35_bpp${BEST_BPP}_reconstructed.jpg"

cp "$BEST_JAI" "$FINAL_JAI"
python -m src.reco.coders.decoder "$FINAL_JAI" "$FINAL_PNG" >/dev/null

python - "$FINAL_PNG" "$FINAL_JPG" "$INPUT" <<'PY'
from PIL import Image
import sys

src_png = sys.argv[1]
dst_jpg = sys.argv[2]
orig = sys.argv[3]

orig_im = Image.open(orig)
dpi = orig_im.info.get("dpi", (96, 96))

im = Image.open(src_png).convert("RGB")

# High JPEG quality and 4:4:4 chroma are used here to avoid adding obvious
# extra degradation after the JPEG AI reconstruction step.
im.save(dst_jpg, quality=98, subsampling=0, optimize=True, dpi=dpi)
print(f"Saved JPG: {dst_jpg}, size={im.size}, dpi={dpi}")
PY

echo
echo "Done."
echo "Source size: $SRC_SIZE B"
echo "Target JAI max size: $TARGET_SIZE B"
echo "Chosen BPP x100: $BEST_BPP"
echo "Actual JAI size: $BEST_SIZE B"
echo "JAI: $FINAL_JAI"
echo "PNG: $FINAL_PNG"
echo "JPG: $FINAL_JPG"
echo
ls -lh "$FINAL_JAI" "$FINAL_PNG" "$FINAL_JPG"
