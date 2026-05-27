Short test for SPI regfile (FPGA) and host

Compile & run (single-file test at `main.c`):

sudo apt install libbcm2835-dev
gcc -o spi_demo main.c -l bcm2835
sudo ./spi_demo    # optional arg: speed percent (default 50)

Expected output (approx):
- write(speed,50)
- read(encoders) -> 1
- read(speed) -> 50

The FPGA also supports an echo-flip demo at addr 0x00 (bitwise-NOT), used internally.
