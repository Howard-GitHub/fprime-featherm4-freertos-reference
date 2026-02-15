#!/bin/bash
# fix.sh — Pre-build setup for STM32 Arduino sketch directory
# Run this from the project root before `fprime-util generate` when the build directory is clean.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-fprime-automatic-FeatherM4_FreeRTOS"
SKETCH_DIR="${BUILD_DIR}/arduino-cli-sketch/sketch"

# 1. Create the sketch directory structure
mkdir -p "${SKETCH_DIR}"

# 2. Create the build.opt file with the sketch include path
echo "-I${SKETCH_DIR}" > "${SKETCH_DIR}/build.opt"

# 3. Create the variant.h wrapper that redirects to the board-specific variant header
cat > "${SKETCH_DIR}/variant.h" << 'EOF'
#ifndef _VARIANT_ARDUINO_STM32_
#define _VARIANT_ARDUINO_STM32_

#ifdef VARIANT_H  
#undef VARIANT_H
#endif

// Force include the real variant header
#include "variant_NUCLEO_H723ZG.h"

#endif /* _VARIANT_ARDUINO_STM32_ */
EOF

echo "Pre-build setup complete: ${SKETCH_DIR}"