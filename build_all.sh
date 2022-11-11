#!/bin/bash

echo "Initializing submodules"
git submodule update --init AFLplusplus/ afl_ghidra_emu/ bench-harness/ ghidra/ icicle-emu/ sysroots/ fuzzware/ fuzzware-experiments/
pushd ghidra/; git submodule update --init Ghidra/Processors/xtensa; popd

echo "Building Icicle"
cargo build --release --manifest-path=icicle-emu/Cargo.toml

echo "Building AFLplusplus, including all versions of QEMU"
pushd AFLplusplus; { NO_PYTHON=1 make afl-fuzz; \
    NO_PYTHON=1 CPU_TARGET=x86_64 make qemu-only; \
    cp afl-qemu-trace afl-qemu-trace-x86_64; \
    NO_PYTHON=1 CPU_TARGET=aarch64 make qemu-only; \
    cp afl-qemu-trace afl-qemu-trace-aarch64; \
    NO_PYTHON=1 CPU_TARGET=riscv64 make qemu-only; \
    cp afl-qemu-trace afl-qemu-trace-riscv64; \
    NO_PYTHON=1 CPU_TARGET=mipsel make qemu-only; \
    cp afl-qemu-trace afl-qemu-trace-mipsel; \
}; popd

# Build benchmarking harness
echo "Building benchmark harness tool"
cargo build --release --manifest-path=bench-harness/Cargo.toml
cargo build --release --target=x86_64-unknown-linux-musl --manifest-path=bench-harness/agent/Cargo.toml --bin agent
# Copy agent tool into docker rootfs
cp ./bench-harness/target/x86_64-unknown-linux-musl/release/agent ./bench-harness/data/fuzzing-rootfs/
cp ./bench-harness/target/x86_64-unknown-linux-musl/release/agent ./bench-harness/data/ghidra-rootfs/
# Copy xtensa processor specification into ghidra rootfs
cp -r ./ghidra/Ghidra/Processors/xtensa/ ./bench-harness/data/ghidra-rootfs/xtensa
# Make cache dir now to ensure that it has the correct permissions later
mkdir ./bench-harness/.harness-cache

# Building afl_ghidra_emu
pushd afl_ghidra_emu/afl_bridge_external/; make; popd
cp afl_ghidra_emu/afl_bridge_external/afl_bridge_external ./bench-harness/data/ghidra-rootfs/afl_bridge_external
cp afl_ghidra_emu/afl_bridge_external/afl_bridge_external ./bench-harness/data/ghidra-rootfs/afl_bridge_external
