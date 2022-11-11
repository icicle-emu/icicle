ICICLE_ARCH='msp430-none' \
    GHIDRA_SRC='../../ghidra' \
    MSP430_MCU='../../msp430-mcu/cc430f6137.ron' \
    MSP430_FIXED_SEED='0x670d7c8767aa7116' \
    ../../icicle-emu/target/release/afl-icicle-trace "goodwatch_crashing_input_$1" -- ../../sysroots/msp430/goodwatch.elf
