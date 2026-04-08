#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$ROOT_DIR/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
COMPILER_ROOT="$(cd "$REPO_ROOT/../compiler" && pwd)"
ASM_SRC="${ASM_SRC:-$BUILD_DIR/safe_hardware_from_compiler.asm}"

mkdir -p "$BUILD_DIR"

echo "==> compile safe_hardware.txt -> $ASM_SRC"
(
    cd "$COMPILER_ROOT"
    # Deterministic dict iteration / stable register coloring across runs.
    export PYTHONHASHSEED=0
    uv run python -m compiler.main safe_hardware.txt 2>&1 | awk '/^--- codegen ---$/{p=1;next} p'
) > "$ASM_SRC"

echo "==> assemble -> $BUILD_DIR/program.hex"
python3 "$REPO_ROOT/assembler/assembler.py" "$ASM_SRC" "$BUILD_DIR/program.hex"

echo "==> iverilog + vvp cpu_compiler_safe_hw_tb"
iverilog -g2012 \
    -o "$BUILD_DIR/cpu_compiler_safe_hw_tb.out" \
    "$ROOT_DIR/test/cpu_compiler_safe_hw_tb.v" \
    "$ROOT_DIR/cpu.v" \
    "$ROOT_DIR/cu.v" \
    "$ROOT_DIR/register.v" \
    "$ROOT_DIR/memory.v" \
    "$ROOT_DIR/alu.v"

(
    cd "$BUILD_DIR"
    vvp cpu_compiler_safe_hw_tb.out
)
