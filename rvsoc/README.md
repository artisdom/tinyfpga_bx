# PicoRV32 SoC on the TinyFPGA BX

A RISC-V computer in the FPGA: a PicoRV32 CPU (RV32IM, 24 MHz) with 8 KB of
RAM, the on-board LED, and a USB serial port built from logic, no extra
hardware. The firmware is a small C shell you talk to from the PC.

```
make          # firmware + bitstream -> build/top.bin
make sim      # run the firmware on the SoC in iverilog (~20 s)
make prog     # press the board's reset button first, then flash
```

Then open the port with a terminal program that uses raw mode and press Enter:

```bash
picocom /dev/serial/by-id/usb-1d50_6130-if00
```

```
> primes 10000
1229 primes below 10000 in 0.486 s
> mandel
...
drawn in 0.216 s
```

Commands: `help`, `info`, `led [on|off|toggle]`, `blink [n]`, `uptime`,
`peek <addr>`, `poke <addr> <value>`, `primes [n]`, `mandel`.

## How it fits together

```
16 MHz ─ PLL ─┬─ 48 MHz ─ usb_serial (USB CDC core) ─ USB pins
              │                 │  ▲
              │           stream_cdc ×2 (toggle handshake)
              │                 ▼  │
              └─ 24 MHz ─ soc: PicoRV32 ─ 8 KB RAM / LED / serial regs
```

| Address       | What                                                       |
|---------------|------------------------------------------------------------|
| `0x0000_0000` | RAM, 8 KB: code, data and stack, preloaded with firmware   |
| `0x1000_0000` | LED, bit 0                                                 |
| `0x2000_0000` | serial data: write sends a byte, read takes one            |
| `0x2000_0004` | serial status: bit 0 byte received, bit 1 ready to send    |

- `rtl/soc.v`: CPU, RAM and registers; the serial side is a plain valid/ready
  byte stream so `sim/tb.v` can drive it without USB.
- `rtl/top.v`: clocks, resets, clock-domain crossings, USB.
- `rtl/usb_serial.v`: wraps the third-party USB core and resets it on a USB
  bus reset, so the board can re-enumerate after the host resets the port
  (without it, the board was stuck until its reset button was pressed;
  recovery with the fix in place has not been exercised yet).
- `firmware/`: `start.S`, `main.c`, `link.ld`; built with clang/lld, no libc.

## Things learned the hard way

- **Two clocks.** The CPU with multiply/divide tops out around 41–46 MHz on
  the LP8K, but USB needs 48 MHz, so the CPU runs from the PLL's half-rate
  output and bytes cross between the domains in `stream_cdc`.
- **`-noflatten`.** Flattened together with the CPU, the USB core's receive
  path synthesizes to twice the logic depth and misses 48 MHz (~43 MHz).
  Keeping the hierarchy gets it to ~50 MHz.
- **Silent until a keypress.** Anything that opens the port before your
  terminal does (ModemManager, a `cat` in cooked mode) may have echo on and
  will feed the CPU's own output back to it as commands.
- **Reflashing** needs the reset button: the board's bootloader only runs
  after reset, and this design replaces it on USB with the same 1d50:6130 ID.
