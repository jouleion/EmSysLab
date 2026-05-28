#!/bin/bash

# simple compile/flash script (copied from assignment_10, with modprobe)

sudo modprobe -r spi_bcm2835 || true

sudo dtparam spi=off

# also add other verliog files if included.
yosys -p 'synth_ice40 -top TopEntity -json ice40.json' TopEntity.v PWM_motordriver.v

nextpnr-ice40 --hx8k --json ice40.json --pcf ico-jiwy.pcf --pcf-allow-unconstrained --asc ice40.asc

icepack ice40.asc ice40.bin

../icoprog/icoprog -R


../icoprog/icoprog -p < ice40.bin

sudo dtparam spi=on || true

sudo modprobe spi_bcm2835 || true

exit 0
