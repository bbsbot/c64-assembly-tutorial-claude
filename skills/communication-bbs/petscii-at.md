# Skill: PETSCII, AT Commands & BBS Logic

## Purpose
To handle the "Software" layer of communications. This skill enables Claude to translate between character sets and manage the Hayes AT command set used by modern C64 WiFi modems (like the WiModem64).

## Character Set Translation
- **PETSCII vs. ASCII:** The C64 uses PETSCII. Most BBSs and modems use ASCII.
- **Conversion Rule:**
    - To convert PETSCII to ASCII: If $41-$5A (Uppercase), add $20. If $C1-$DA (Graphics), map to corresponding ASCII.
    - Claude should provide a `Translate_Table` in assembly for high-speed conversion.
- **Control Codes:** Handle PETSCII color codes (e.g., CTRL+1 for Black) and map them to ANSI escape sequences if the user is building a terminal for non-C64 systems.

## Hayes AT Command Set
When the user wants to "Dial" or "Configure" the modem, Claude should use these standard strings:
- `AT`: Attention (Test connection)
- `ATDT[address]`: Dial/Connect to a Telnet BBS.
- `+++`: Escape to command mode.
- `ATH`: Hang up.
- `AT$V`: Often used in WiFi modems to show firmware version.

## BBS UI Logic (The "Petscii Art" Factor)
- **Screen Codes:** Remind the user that Screen RAM codes ($00-$3F) are different from PETSCII codes ($41-$5A).
- **Formatting:** Provide subroutines for "Center Text," "Clear Line," and "Print Color String" to make BBS menus look professional.

## Example Pattern: Sending a Dial String
```kickasm
// Send "ATDT" followed by address
send_dial:
    ldx #0
next_char:
    lda dial_cmd,x
    beq done
    jsr char_out_rs232 // Defined in rs232-driver.md
    inx
    jmp next_char
done:
    rts

dial_cmd: .text "ATDT"
          .byte 13, 0 // CR and Null terminator

```

## Creative Guidance

Suggest adding "Easter Eggs" or classic PETSCII art banners to the BBS logic to give it an authentic 80s/90s feel.
