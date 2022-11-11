# MSP430 crash analysis

Crashes found in MSP430 binaries by Icicle.

| #   | Target            | Description
| --  | ------            | -----------
| I03 | Goodwatch         | [Incorrect comparison when writing to `dmesg_buffer`](#i03-incorrect-comparison-when-writing-to-dmesg-buffer)
| I04 | Goodwatch         | [Zero message length](#i04-zero-message-length)
| I05 | Goodwatch         | [RNG Overflow](#i05-rng-overflow)
| I06 | Goodwatch         | [Out-of-bounds access in OOK keypress](#i06-out-of-bounds-access-in-ook-keypress)
| I07 | Goodwatch         | [Out-of-bounds access in Stopwatch](#i07-out-of-bounds-access-after-60-hours-in-stopwatch)
| I08 | Goodwatch         | [Out-of-bounds access when displaying DOW](#i08-out-of-bounds-access-when-displaying-day-of-week)
| I09 | Goodwatch         | [Hex viewer application](#i09-hex-viewer-application)
| I10 | Goodwatch         | [PEEK/POKE monitor commands](#i10-peek-and-poke-monitor-commands)
| I11 | H4_PacketProtocol | [Unchecked Interface Index in Get Descriptor](#i11-unchecked-interface-index-in-get-descriptor)
| I12 | H4_PacketProtocol | [Buffer overflow in Set Report](#i12-buffer-overflow-in-set-report)


## Goodwatch


### I03: Incorrect comparison when writing to `dmesg buffer`

* An off-by-one error in `putchar` causes single byte OOB write at `0x2c00`.
* Note: we avoid triggering this during fuzzing by increasing the size of the memory region containing the buffer.

Example call-stack during crash:

```
UnhandledException(code=WriteUnmapped, value=0x2c00):
0x000000c81a: putchar+0x1c
0x000000c832: dmesg_putc+0x6
0x0000009706: tfp_format+0x22
0x000000ad9c: tfp_printf+0x12
0x000000b924: key_scan.part.0+0x68
0x000000cd3c: PORT2_ISR+0x1a
0x0000008e04: <unknown>
```


### I04: Zero message length

* Messages sent to the UART interface with the length field set to zero are handled incorrectly. In the `MSG` state, after storing the byte that was just received at the current `index` in the `uart_buffer` it increments `index` and checks is now equal to `length`, however since the store and increment of `index` occurs before comparing against `length` for zero length messages the `index == length` condition will never be true.

* Eventually `index` will exceed the `uart_buffer` array allowing global variables stored after `uart_buffer` to be modified. This typically results in the program crashing when either the `stdout_putf` or `stdout_putp` function pointers are overwritten and a debug message is printed.

Crashing input:
```
./run_goodwatch.sh I04a
```

Call-stack during crash:

```
UnhandledException(code=InvalidInstruction)
0x000000d3d3: <unknown>
0x0000009648: putchw+0x40
0x0000009826: tfp_format+0x142
0x000000ad9c: tfp_printf+0x12
0x000000b924: key_scan.part.0+0x68
0x000000cd3c: PORT2_ISR+0x1a
0x0000008e04: <unknown>
```

* Another way for program to crash is for `appindex` (or `subindex`) to be overwritten, causing a crash the next `applet` is loaded using `appindex` (e.g. in `app_draw`).

Call-stack during crash:
```
UnhandledException(code=InvalidInstruction)
0x000000531c: <unknown>
0x0000009a96: app_init+0xe
0x000000c0a8: settime_draw+0x28
0x0000009b0a: app_draw+0x3e
0x000000ce78: watchdog_timer+0x6a
0x0000008e04: <unknown>
```

### I05: RNG Overflow:

* The `RANDINT` monitor command causes the firmware to generate and send a list of random numbers. However, the number of random values to generate is controlled by the received command. If the number of values to generate is too large, then `rints` will exceed the space reserved for the stack triggering an OOB write.

Crashing input:
```
./run_goodwatch.sh I05
```

Call-stack during crash:
```
UnhandledException(code=WriteUnmapped, value=0x6e6a)
0x000000cbd4: USCI_A0_ISR+0x24c (inlined `send_randint`)
0x0000008e04: <unknown>
```


### I06: Out-of-bounds access in `ook keypress`:

* The OOK application sends a pre-configured OOK packet from `button_array` when one of the numeric keys (0-9) is pressed. However the `ook_keypress` does not validate that the key pressed is in bounds of the `button_array` array. There are 10 numeric buttons (0-9)  `button_array` only contains 9 entries.

* `button_array` contains an array of pointers, when the `9` button is pressed on the OOK application the program `setrate` function will read a pointer out-of-bounds of the `button_array` and dereference it causing the program to crash.

* The pointer it reads is the first value from `ook_settings` (0x3012) which does not exist in memory.

Crashing input:
```
./run_goodwatch.sh I06
```

Call-stack during crash:
```
UnhandledException(code=ReadUnmapped, value=0x3012)
0x000000b87a: ook_keypress+0x2c
0x000000cd7e: PORT2_ISR+0x5c
0x0000008e04: <unknown>
```

### I07: Out-of-bounds access after 60 hours in stopwatch:

* The firmware implements integer to binary-coded-decimal (BCD) operation using a lookup table, however the lookup table (`bcdtable`) only contains values for converting integers from 0 to 59. For converting seconds and minutes this is fine since these values roll over at 60 when counting, however the `hour` variable can exceed 60 causing an index out-of-bounds.

* This bug was only found by the fuzzer as a side-effect of the corruption caused by the Zero length message bug. In the in crash found by the fuzzer both the `min` and `hour` global variables are corrupted when `uart_buffer` is overflowed.

Crashing input:
```
./run_goodwatch.sh I07
```

Call-stack during crash:
```
UnhandledException(code=ReadUnmapped, value=0x4b57)
0x000000a3e4: stopwatch_draw+0x9e
0x0000009b0a: app_draw+0x3e
0x000000ce78: watchdog_timer+0x6a
0x0000008e04: <unknown>
```

### I08: Out-of-bounds access when displaying day of week:

* False positive bug caused by the fuzzer generating a large value for the `RTCDOW` peripheral.

* Pressing button `9` on the clock application attempts to draw the current day of the week on the LCD. The day of the week is read directly from the RTCDOW register of the RTC peripheral, the datasheet for this register specifies the value return is between 0-6, however during fuzzing the value of this register is unconstrained. Since the value is used as an index into the `dayofweek` array, if the fuzzer generates a value larger than 6 for the `RTCDOW` register the program will read a pointer outside of the `daysofweek` array resulting in a (false-positive) crash.

* This crash can occur as part of both `clock_keypress` and `hebrew_keypress`.

Crashing input:
```
./run_goodwatch.sh I08a
```

Call-stack during crash:
```
UnhandledException(code=ReadUnmapped, value=0x5150)
0x0000009e6e: lcd_string+0x8
0x000000c1dc: clock_keypress+0x6c
0x000000cd7e: PORT2_ISR+0x5c
0x0000008e04: <unknown>
```

Crashing input:
```
./run_goodwatch.sh I08b
```

Call-stack during crash:
```
UnhandledException(code=ReadPerm, value=0x1006)
0x0000009e6e: lcd_string+0x8
0x000000b2aa: hebrew_keypress+0x116
0x000000c48c: clock_keypress+0x31c
0x000000cd7e: PORT2_ISR+0x5c
0x0000008e04: <unknown>
```

### I09: Hex viewer application:

* The Hex Viewer application allows viewing memory from a user control address. By navigating the Hex Viewer to an unmapped address, it causes the emulator to report a crash.

Crashing input:
```
./run_goodwatch.sh I09
```

Call-stack during crash:
```
UnhandledException(code=ReadUnmapped, value=0x7000)
0x0000009c74: hex_draw.part.0+0x3c
0x0000009c88: hex_draw+0x8
0x0000009b0a: app_draw+0x3e
0x000000cd8c: PORT2_ISR+0x6a
0x0000008e04: <unknown>
```

### I10: PEEK and POKE Monitor commands:

* The monitor PEEK/POKE commands allow reading/writing to arbitrary memory respectively. However, this behaviour is an intended feature rather than a bug (since the monitor interface is designed for debugging).

Crashing input for `PEEK`:
```
./run_goodwatch.sh I10a
```

Call-stack during crash:
```
UnhandledException(code=ReadUnmapped, value=0x5100)
0x000000cb00: USCI_A0_ISR+0x178
0x0000008e04: <unknown>
```

Crashing input for `POKE`:
```
./run_goodwatch.sh I10b
```

Call-stack during crash:
```
UnhandledException(code=WritePerm, value=0x4b00)
0x000000cb32: USCI_A0_ISR+0x1aa
0x0000008e04: <unknown>
```


## H4_PacketParser

### I11: Unchecked Interface Index in Get Descriptor:

* The interface index is unchecked in several of the `Get_Descriptor` handlers. This can cause an out-of-bounds access. For example:

GetHidDescriptor:
```
./run_H4_PacketProtocol.sh I11a
```

Call-stack during crash:
```
UnhandledException(code=ReadUninitialized, value=0xe90e)
0x0000011176: usbSendNextPacketOnIEP0 at ./USB_API/USB_Common/usb.c:1082.13
0x0000011c12: usbGetHidDescriptor at ./USB_API/USB_HID_API/UsbHidReq.c:78.5
0x0000010fb0: usbDecodeAndProcessUsbRequest at ./USB_API/USB_Common/usb.c:1655.5
0x0000011724: SetupPacketInterruptHandler at ./USB_config/UsbIsr.c:250.5
0x0000004410: iUsbInterruptHandler at ./USB_config/UsbIsr.c:88.9
0x0000004572: _c_int00_noargs
```

GetReportDescriptor:
```
./run_H4_PacketProtocol.sh I11b
```

Call-stack during crash:
```
UnhandledException(code=ReadUninitialized, value=0xa44c)
0x0000011c28: usbGetReportDescriptor at ./USB_API/USB_HID_API/UsbHidReq.c:85.5
0x0000010fb0: usbDecodeAndProcessUsbRequest at ./USB_API/USB_Common/usb.c:1655.5
0x0000011724: SetupPacketInterruptHandler at ./USB_config/UsbIsr.c:250.5
0x00000044fe: iUsbInterruptHandler at ./USB_config/UsbIsr.c:166.9
0x0000004572: _c_int00_noargs
```

### I12: Buffer overflow in Set Report:

* After receiving a `Set_Report` packet the firmware assigns a buffer to store the report into `pbOEP0Buffer`, and the length of the report in `wBytesRemainingOnOEP0`. However, the firmware does not check if the reports fits into the assigned buffer, causing a buffer overflow when the buffer is later written to in `usbReceiveNextPacketOnOEP0`.

In the crashing input below, the address of 8-byte array (`0x24a4: abUsbRequestIncomingData`) is assigned to `pbOEP0Buffer`, after overflowing the array, a function pointer (`0x24b4: USB_RX_memcpy`) is corrupted, causing a crash when the function pointer is later called.

```
./run_H4_PacketProtocol.sh I12
```

Call-stack during crash:
```
UnhandledException(code=InvalidInstruction, value=0xf95b7)
0x00000f95b7: <unknown>
0x0000011066: HidCopyUsbToBuff at ./USB_API/USB_HID_API/UsbHid.c:417.5
0x0000010172: USBHID_receiveData at ./USB_API/USB_HID_API/UsbHid.c:577.13
0x000001026a: main at ./main.c:115.25
0x0000004572: _c_int00_noargs
```
