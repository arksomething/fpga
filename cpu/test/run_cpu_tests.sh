#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

mkdir -p "$BUILD_DIR"

# Provide a default image for memory.v; testbenches override memory contents.
: > "$BUILD_DIR/program.hex"
for _ in $(seq 1 256); do
    echo "F000" >> "$BUILD_DIR/program.hex"
done

tests=(
    cpu_edge_cases_tb
    cpu_program_smoke_tb
    cpu_call_stack_tb
)

for test_name in "${tests[@]}"; do
    echo "==> $test_name"
    iverilog -g2012 \
        -o "$BUILD_DIR/$test_name.out" \
        "$ROOT_DIR/test/$test_name.v" \
        "$ROOT_DIR/cpu.v" \
        "$ROOT_DIR/cu.v" \
        "$ROOT_DIR/register.v" \
        "$ROOT_DIR/memory.v" \
        "$ROOT_DIR/alu.v"

    (
        cd "$BUILD_DIR"
        vvp "$test_name.out"
    )
done

echo "All CPU tests passed."
