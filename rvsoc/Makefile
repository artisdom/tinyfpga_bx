# PicoRV32 SoC for the TinyFPGA BX.
#   make        build firmware and bitstream -> build/top.bin
#   make sim    run the firmware on the SoC in iverilog
#   make prog   flash the bitstream with tinyprog
#   make clean  remove build outputs

BUILD     := build
MEM_WORDS := 2048

OSS_CAD ?= $(HOME)/opt/oss-cad-suite
export PATH := $(OSS_CAD)/bin:$(PATH)

TP  := ../third_party
USB := $(addprefix $(TP)/usbserial/, edge_detect.v serial.v usb_fs_in_arb.v \
	usb_fs_in_pe.v usb_fs_out_arb.v usb_fs_out_pe.v usb_fs_pe.v usb_fs_rx.v \
	usb_fs_tx_mux.v usb_fs_tx.v usb_reset_det.v usb_serial_ctrl_ep.v \
	usb_uart_bridge_ep.v usb_uart_core.v)
CPU := $(TP)/picorv32/picorv32.v
RTL := rtl/top.v rtl/pll.v rtl/soc.v rtl/stream_cdc.v rtl/usb_serial.v $(CPU) $(USB)

CC      := clang
CFLAGS  := --target=riscv32-unknown-elf -march=rv32im -mabi=ilp32 -mno-relax \
	-Os -ffreestanding -nostdlib -Wall -Wextra
LDFLAGS := -fuse-ld=lld -Wl,-T,firmware/link.ld
FW_SRC  := firmware/start.S firmware/main.c

all: $(BUILD)/top.bin

# ---- firmware

$(BUILD)/firmware.elf: $(FW_SRC) firmware/link.ld | $(BUILD)
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(FW_SRC)

$(BUILD)/firmware.bin: $(BUILD)/firmware.elf
	llvm-objcopy -O binary $< $@

$(BUILD)/firmware.hex: $(BUILD)/firmware.bin firmware/bin2hex.py
	python3 -I firmware/bin2hex.py $< $@ $(MEM_WORDS)

# ---- simulation

$(BUILD)/tb.vvp: sim/tb.v rtl/soc.v $(CPU) | $(BUILD)
	iverilog -g2012 -o $@ -s tb sim/tb.v rtl/soc.v $(CPU)

sim: $(BUILD)/tb.vvp $(BUILD)/firmware.hex
	vvp -n $<

# ---- bitstream
# -noflatten keeps the USB core's logic separate from the CPU's; flattened,
# the USB receive path lands at ~43 MHz instead of meeting 48 MHz.

$(BUILD)/top.json: $(RTL) $(BUILD)/firmware.hex
	yosys -q -l $(BUILD)/yosys.log -p "synth_ice40 -top top -noflatten -json $@" $(RTL)

$(BUILD)/top.asc: $(BUILD)/top.json pins.pcf
	nextpnr-ice40 -q -l $(BUILD)/nextpnr.log --lp8k --package cm81 \
		--pcf pins.pcf --json $< --asc $@

$(BUILD)/top.bin: $(BUILD)/top.asc
	icepack $< $@

$(BUILD):
	mkdir -p $@

prog: $(BUILD)/top.bin
	tinyprog -p $<

clean:
	rm -rf $(BUILD)

.PHONY: all sim prog clean
