#!/bin/bash
set -euo pipefail

# compile_on_raspi.sh
# Safely disable Raspberry Pi SPI kernel driver, build the FPGA bitstream,
# flash it using icoprog, and restore the SPI driver on exit.

ICOPROG=../icoprog/icoprog
PCF=ico-jiwy.pcf
TOP=SPI
YOSYS_CMD="yosys -p 'synth_ice40 -top ${TOP} -json ice40.json' ${TOP}.v"
PNR_CMD="nextpnr-ice40 --hx8k --json ice40.json --pcf ${PCF} --asc ice40.asc"

echo "[INFO] Preparing to build and flash FPGA. This script will temporarily remove the Raspberry Pi SPI kernel module."

if ! command -v ${ICOPROG} >/dev/null 2>&1; then
	echo "[WARN] icoprog not found at ${ICOPROG}. Make sure icoprog is built and path is correct." >&2
fi

cleanup() {
	echo "[INFO] Restoring SPI kernel driver..."
	sudo modprobe spi_bcm2835 || true
}

trap cleanup EXIT

echo "[INFO] Unloading SPI kernel module (spi_bcm2835) to free /dev/spidev..."
sudo modprobe -r spi_bcm2835 || echo "[INFO] spi_bcm2835 was not loaded"

echo "[INFO] Building FPGA bitstream..."
${YOSYS_CMD}
${PNR_CMD}
icepack ice40.asc ice40.bin

echo "[INFO] Flashing FPGA... (icoprog will be used)"
if [ -x "${ICOPROG}" ]; then
	${ICOPROG} -R
	${ICOPROG} -p < ice40.bin
else
	echo "[ERROR] icoprog executable not found or not executable: ${ICOPROG}" >&2
	exit 2
fi

echo "[INFO] Flash complete. SPI kernel module will be reloaded by cleanup()."

exit 0