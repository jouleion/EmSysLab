Simple SPI regfile test (FPGA) and host client

UPLOAD VERILOG
time sudo ./compile_on_raspi.sh

Build on Raspberry Pi:

sudo apt install libbcm2835-dev
gcc -o spi_client main.c -l bcm2835

Run (use sudo):

sudo ./spi_client

Or one-shot write:

sudo ./spi_client write <speed(0..127)> <dir(0|1)> <enable(0|1)>

Interactive commands (type at the prompt):

- read           Read encoders (16-bit)
- write S D E    Write speed S(0..127), D=direction, E=enable
- status         Read back device `REG_SPEED` and `REG_FLAGS`
- help           Show help
- quit | exit    Quit

Short readup:
- Write: host sends command 0x81 then two data bytes (speed+dir, flags). Slave stores them to regs.
- Read: host sends command byte with W=0 (addr), then clocks dummy bytes; slave returns register bytes LSB->MSB.



1) Test — SPI write (one-shot from `main.c`)

 - Run the one-shot write to set speed/direction/enable:

	 sudo ./spi_client write <speed> <dir> <enable>

 - Fields and mapping (REG_SPEED at addr 1, REG_FLAGS at addr 2):
	 - REG_SPEED (8 bits): [bit7 = DIR][bits6:0 = SPEED(0..127)]
	 - REG_FLAGS (8 bits): [bit0 = ENABLE][bit1 = BRAKE]

 - MOSI bytes sent (MSB-first). Use both hex and decimal for clarity:
	 - Command byte: 0x80 | addr -> 0x81 (hex) = 129 (dec)
	 - Data byte 0: (DIR<<7) | (SPEED & 0x7F)  (hex/dec depends on values)
	 - Data byte 1: FLAGS (bit0=ENABLE, bit1=BRAKE)

	 Example: `sudo ./spi_client write 50 1 1` (speed=50, dir=1, enable=1)
	 - Data byte 0 = (1<<7) | 50 = 0xB2 (hex) = 178 (dec)
	 - Data byte 1 = (enable=1) -> 0x01 (hex) = 1 (dec)
	 - Full MOSI sequence: 0x81, 0xB2, 0x01  (hex) = 129, 178, 1 (dec)

 - MISO (what PulseView will show):
	 - At CS start the slave transmits 0xFE (254 dec) by default, so the first MISO byte is commonly 0xFE.
	 - During a write the MISO bytes are not meaningful for data confirmation; use the `status` read to verify writes.

2) Test — SPI read (encoder read)

 - Purpose: read a 16-bit value stored at addresses 0x10 (LSB) and 0x11 (MSB).

 - MOSI (hex / dec): [addr] [0x00] [0x00]
	 - Example command to read encoders: 0x10, 0x00, 0x00 (hex) = 16, 0, 0 (dec)

 - Expected MISO (hex / dec):
	 - Byte0 (during command): usually 0xFE (254 dec)
	 - Byte1: encoder LSB (e.g., 0x23 hex = 35 dec)
	 - Byte2: encoder MSB (e.g., 0x01 hex = 1 dec)

	 Example: encoder == 0x0123 → MISO: 0xFE, 0x23, 0x01 (hex) = 254, 35, 1 (dec)

3) Test — write then verify via status read

 - Procedure:
	 1. Send write: `sudo ./spi_client write 127 1 1` (speed=127, dir=1, enable=1)
			- MOSI: 0x81, 0xFF, 0x01 (hex) = 129, 255, 1 (dec)
	 2. Read back `REG_SPEED` (addr 0x01): MOSI 0x01, 0x00  (hex) = 1, 0 (dec)
			- Expected MISO: 0xFE, 0xFF (hex) = 254, 255 (dec) → speed=127, dir=1
	 3. Read back `REG_FLAGS` (addr 0x02): MOSI 0x02, 0x00  (hex) = 2, 0 (dec)
			- Expected MISO: 0xFE, 0x01 (hex) = 254, 1 (dec) → enable=1

 - If the readbacks show the values you wrote (in decimal or hex), the FPGA received the command successfully.

Notes on capture settings:
 - SPI mode: 0 (CPOL=0, CPHA=0), MSB-first.
 - Use a sample rate high enough to resolve SCLK pulses (PulseView default for Pi GPIO captures is fine).

