ICICLE_ARCH='msp430-none' \
    GHIDRA_SRC='../../ghidra' \
    MSP430_MCU='../../msp430-mcu/msp430f5529.ron' \
    MSP430_FIXED_SEED='0x670d7c8767aa7116' \
    ../../icicle-emu/target/release/afl-icicle-trace "H4_PacketProtocol_crashing_input_$1" -- ../../sysroots/msp430/H4_PacketProtocol.out
