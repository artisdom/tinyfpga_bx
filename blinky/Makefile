# Build and flash for the TinyFPGA BX.
#   make        synthesize, place & route, pack -> build/top.bin
#   make prog   flash the bitstream with tinyprog
#   make clean  remove build outputs

PROJ    := top
SOURCES := blinky.v
PCF     := pins.pcf
BUILD   := build

OSS_CAD ?= $(HOME)/opt/oss-cad-suite
export PATH := $(OSS_CAD)/bin:$(PATH)

all: $(BUILD)/$(PROJ).bin

$(BUILD)/$(PROJ).json: $(SOURCES) | $(BUILD)
	yosys -q -l $(BUILD)/yosys.log -p "synth_ice40 -top $(PROJ) -json $@" $(SOURCES)

$(BUILD)/$(PROJ).asc: $(BUILD)/$(PROJ).json $(PCF)
	nextpnr-ice40 -q -l $(BUILD)/nextpnr.log --lp8k --package cm81 --freq 16 \
		--pcf $(PCF) --json $< --asc $@

$(BUILD)/$(PROJ).bin: $(BUILD)/$(PROJ).asc
	icepack $< $@

$(BUILD):
	mkdir -p $@

prog: $(BUILD)/$(PROJ).bin
	tinyprog -p $<

clean:
	rm -rf $(BUILD)

.PHONY: all prog clean
