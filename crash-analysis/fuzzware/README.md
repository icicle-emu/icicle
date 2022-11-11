# Fuzzware crash analysis

Crashes found with Fuzzware using Icicle as the backend.

## Reproduction

All the bugs in the P2IM dataset discovered Fuzzware. See [fuzzware-experiments/04-crash-analysis](https://github.com/fuzzware-fuzzer/fuzzware-experiments/tree/main/04-crash-analysis) for additional details.

Note: follow the details in https://github.com/icicle-emu/fuzzware to configure Fuzzware.


| #  | Target          | Description           | Command
| -  | ------          | -----------           | --------
| 11 | CNC             | Stack OOB write       | `fuzzware emu -v -c CNC_config.yml CNC_crashing_input_11`
| 12 | Gateway         | OOB write in HAL      | `fuzzware emu -v -c Gateway_config_24.yml Gateway_crashing_input_12`
| 13 | Heat Press      | Buffer overflow       | `fuzzware emu -v -c Heat_Press_config_13.yml Heat_Press_crashing_input_13`
| 14 | PLC             | Missing bounds check  | `fuzzware emu -v -c PLC_config_15.yml PLC_crashing_input_14`
| 15 | PLC             | Missing bounds check  | `fuzzware emu -v -c PLC_config_15.yml PLC_crashing_input_15`
| 16 | PLC             | Missing bounds check  | `fuzzware emu -v -c PLC_config_15.yml PLC_crashing_input_16`
| 17 | PLC             | Missing bounds check  | `fuzzware emu -v -c PLC_config_15.yml PLC_crashing_input_17`
| 18 | CNC             | CNC input validation  | `fuzzware emu -v -c CNC_config.yml CNC_crashing_input_18`
| 19 | Soldering Iron  | Expired pointer use   | `fuzzware emu -v -c Soldering_Iron_config_19.yml Soldering_Iron_crashing_input_19`
| 20 | Robot           | Initialization race   | `fuzzware emu -v -c Robot_config.yml Robot_crashing_input_20`
| 21 | Gateway         | Missing pointer check | `fuzzware emu -v -c Gateway_config_21.yml Gateway_crashing_input_21`
| 22 | Gateway         | Missing pointer check | `fuzzware emu -v -c Gateway_config_22.yml Gateway_crashing_input_22`
| 23 | Gateway         | Expired pointer use   | `fuzzware emu -v -c Gateway_config_23.yml Gateway_crashing_input_23`
| 24 | Gateway         | Missing pointer check | `fuzzware emu -v -c Gateway_config_24.yml Gateway_crashing_input_24`
| 25 | PLC             | Missing initialization| `fuzzware emu -v -c PLC_config_25.yml PLC_crashing_input_25`
| 26 | Reflow Oven     | Missing pointer check | `fuzzware emu -v -c Reflow_Oven_config.yml Reflow_Oven_crashing_input_26`

## New bugs

Additional bugs discovered by Icicle not reported by Fuzzware.

| #   | Target          | Description
| --  | ------          | -----------
| I01 | Console         | [Input validation](#i01-console)
| I02 | Soldering Iron  | [Buffer overflow](#i02-soldering-iron) (false-positive)


### I01: Console

As part of the `rtc settime` command, the firmware reads a date from the user in the form `YYYY-MM-DD HH:MM:SS` without checking whether the parsed date is valid.

* In the `dow` function, the month is as an index into the `dow::t` global array. If the month is >12, then this causes an out-of-bounds access.

#### Example crashing input:

```
fuzzware emu -v -c Console_config_I01.yml Console_crashing_input_I01
```

In the example input the command parser reads the following line from the fuzzer:

```
rtc setalarm\x015-955795a\xe1\xe4\xff\xff\x0c\x89\x89{\xf3\x89\x89\x89\x89\x89\x89JaA\xe1AA
```

The `_parse_time` function interprets this as:

```
   year   month    day       hour      min       sec
\x01[5]-[955795]a[\xe1]\xe4[\xff\]xff[\x0c]\x89[\x89]{\xf3\x89\x89\x89\x89\x89\x89JaA\xe1AA
```

The function does not check that separators or the digits are valid (invalid digits are treated as zero). The large month value is then used as an index in `dow` causing an invalid access:

```
UnhandledException(code=ReadUnmapped, value=0x1ffd5898)
0x0000003272: dow at ./sys/shell/commands/sc_rtc.c:42
0x000000337e: _parse_time at ./sys/shell/commands/sc_rtc.c:69
0x0000003428: _rtc_setalarm at ./sys/shell/commands/sc_rtc.c:101
0x00000035f2: _rtc_handler at ./sys/shell/commands/sc_rtc.c:171
0x0000002d3a: handle_input_line at ./sys/shell/shell.c:208
0x0000002eb6: shell_run at ./sys/shell/shell.c:294
0x00000023a0: main at ./examples/default/main.c:48
0x0000000f6a: main_trampoline at ./core/kernel_init.c:60
0x0000000fca: kernel_init at ./core/kernel_init.c:94
0x0000000a0c: reset_handler_default at ./cpu/cortexm_common/vectors_cortexm.c:127
```

### I02: Soldering Iron

* In `gui_solderingMode` the firmware draws a heat symbol on the LCD based on the current tip PWM value, using: `lcd.drawHeatSymbol(getTipPWM())`
* The `getTipPWM` function returns `htim2.Instance->CCR4 & 0xff`, where `CCR4` is a pointer to MMIO memory.
* Inside of `drawHeatSymbol` the value returned by `getTipPWM` is used to compute the bottom coordinate (`y1`) of the call to `drawFilledRect`.
* When the value returned by `getTipPWM` is >162 then calculating `y1` underflows causing a large value to be passed as `y1`.
* This causes `drawFilledRect` to overflow the `OLED.screenBuffer` variable corrupting global variables.
    - The `i2c` pointer for the global variable `accel` may get overwritten causing a crash next time it is accessed (e.g., in `startMOVTask`).

Note: This is crash is a false-positive, since normally the `setTipPwm` function limits the value written to `htim2.Instance->CCR4` to a maximum of 100. However, since the `CCR4` is a peripheral Fuzzware reads the value from the fuzzer.

#### Example crashing input:

```
fuzzware emu -v -c Soldering_Iron_I02.yml Soldering_Iron_crashing_input_I02
```

For this input, the bottom two bytes of the `accel.i2c` pointer (`0x200034e0`) are set to `0x00`. The next time the pointer is read (in `FRToSI2C::Mem_Read`) it points to `0x20000000` instead of the correct address `0x200033e4`. `0x20000000 + 0x4` is then interpreted as the `I2CSemaphore` pointer and dereferenced crashing the program.
