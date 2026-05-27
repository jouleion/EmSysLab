#!/bin/bash
set -e

echo "[INFO] Compiling PWM simulation..."
iverilog -o sim.vvp PWM_Motordriver.v PWM_Motordriver_tb.v

echo "[INFO] Running simulation..."
vvp sim.vvp

GTK_SETUP="pwm_setup.gtkw"
if [ -f "$GTK_SETUP" ]; then
  echo "[INFO] Opening waveform with saved setup..."
  gtkwave signals.vcd "$GTK_SETUP"
else
  echo "[INFO] Opening waveform (no saved setup found)..."
  gtkwave signals.vcd
fi
