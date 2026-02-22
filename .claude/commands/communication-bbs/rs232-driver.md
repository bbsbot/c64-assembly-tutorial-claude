# Skill: RS232 & User Port Communication

## Purpose
This skill provides the technical foundation for serial communication on the C64. It is essential for creating BBS software, terminal emulators, and file transfer utilities using the User Port.

## Hardware Fundamentals
- **CIA 2 (Complex Interface Adapter):** Located at `$DD00`. This chip handles the User Port lines used for RS232.
- **Baud Rate Generation:** The C64 does not have a dedicated hardware UART. High-speed communication (above 2400 baud) requires precise CPU timing and "bit-banging" or specialized Kernal drivers.
- **Pins:** Claude must know the RS232 pin mapping on the User Port (Pins B, C, D, etc.) to assist the user with cabling or emulator configuration.

## Kernal RS232 Integration
For standard terminal applications, Claude should prioritize the Kernal's built-in RS232 buffers:
1. **`OPEN` ($FFC0):** Initializing the channel with baud rate, parity, and stop bit parameters.
2. **`CHKIN` ($FFC6):** Setting the RS232 channel as the current input.
3. **`GETIN` ($FFE4):** Retrieving characters from the 256-byte input buffer.
4. **`CHKOUT` ($FFC9) / `CHROUT` ($FFD2):** Sending characters to the serial line.

## High-Performance Drivers (Non-Kernal)
If the user wants 9600 baud or higher (common for modern WiFi modems), Claude should suggest:
- **UP9600 Style Drivers:** Using the CIA timers to sample the start bit and data bits more aggressively.
- **Interrupt Management:** Disabling the screen (VIC-II fetch) or using stable raster techniques to prevent "jitter" in the serial timing.

## Code Pattern: RS232 Initialization
```kickasm
// Open RS232 at 2400 Baud, 8N1
setup_rs232:
    lda #$00
    sta $0293    // Control Register: 2400 Baud
    lda #$00
    sta $0294    // Command Register: 8 bits, 1 stop, No parity
    
    lda #$02     // File number 2
    ldx #$02     // Device 2 (RS232)
    ldy #$00     // No command
    jsr SETLFS
    
    lda #$00     // No filename
    jsr SETNAM
    jsr OPEN
    bcs handle_error
    rts

```

## BBS Considerations

* **Carrier Detect:** Monitoring CIA 2 registers to see if a modem has "hung up."
* **Buffering:** Implementing large circular buffers in high memory ($C000) or REU to prevent data loss during slow screen renders.
