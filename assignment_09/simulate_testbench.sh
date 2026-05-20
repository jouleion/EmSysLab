#!/bin/bash

set -e

echo "[INFO] Compiling PWM simulation..."

iverilog -o sim.vvp PWM_Motordriver.v PWM_Motordriver_tb.v

echo "[INFO] Running simulation..."

vvp sim.vvp

echo "[INFO] Opening waveform..."

gtkwave signals.vcd