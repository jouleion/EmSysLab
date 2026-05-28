// Simple interactive SPI client for the TopEntity SPI interface
// - Build on Raspberry Pi with bcm2835:
//     sudo apt install libbcm2835-dev
//     gcc -o spi_client main.c -l bcm2835
// - Run with sudo: `sudo ./spi_client` or use the one-shot `write` form

#include <bcm2835.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Defaults
#define BCM_SPI_CHIP_SELECT 1
#define BCM_SPI_TARGET_HZ 500000

static uint16_t bcm_choose_clock_divider(unsigned target_hz) {
	const struct { uint32_t hz; uint16_t div; } table[] = {
		{125000000, BCM2835_SPI_CLOCK_DIVIDER_2},
		{62500000, BCM2835_SPI_CLOCK_DIVIDER_4},
		{31250000, BCM2835_SPI_CLOCK_DIVIDER_8},
		{15625000, BCM2835_SPI_CLOCK_DIVIDER_16},
		{7812500, BCM2835_SPI_CLOCK_DIVIDER_32},
		{3906250, BCM2835_SPI_CLOCK_DIVIDER_64},
		{1953125, BCM2835_SPI_CLOCK_DIVIDER_128},
		{976562, BCM2835_SPI_CLOCK_DIVIDER_256},
		{488281, BCM2835_SPI_CLOCK_DIVIDER_512},
		{244140, BCM2835_SPI_CLOCK_DIVIDER_1024},
		{122070, BCM2835_SPI_CLOCK_DIVIDER_2048},
		{61035, BCM2835_SPI_CLOCK_DIVIDER_4096},
		{30517, BCM2835_SPI_CLOCK_DIVIDER_8192},
		{15258, BCM2835_SPI_CLOCK_DIVIDER_16384},
		{7629, BCM2835_SPI_CLOCK_DIVIDER_32768},
		{3814, BCM2835_SPI_CLOCK_DIVIDER_65536}
	};
	for (unsigned i = 0; i < sizeof(table)/sizeof(table[0]); ++i) {
		if (target_hz >= table[i].hz) return table[i].div;
	}
	return BCM2835_SPI_CLOCK_DIVIDER_65536;
}

int bcm_spi_init(unsigned chip_select, unsigned target_hz) {
	if (!bcm2835_init()) return -1;
	bcm2835_spi_begin();
	bcm2835_spi_setBitOrder(BCM2835_SPI_BIT_ORDER_MSBFIRST);
	bcm2835_spi_setDataMode(BCM2835_SPI_MODE0);
	bcm2835_spi_chipSelect(chip_select ? BCM2835_SPI_CS1 : BCM2835_SPI_CS0);
	uint16_t div = bcm_choose_clock_divider(target_hz);
	bcm2835_spi_setClockDivider(div);
	return 0;
}

void bcm_spi_close(void) {
	bcm2835_spi_end();
	bcm2835_close();
}

int bcm_spi_transfer(char *tx_buf, char *rx_buf, unsigned count) {
	bcm2835_spi_transfernb(tx_buf, rx_buf, count);
	return 0;
}

int bcm_spi_write_reg8(uint8_t address, uint8_t value) {
	unsigned char tx[2], rx[2];
	tx[0] = 0x80 | (address & 0x7F);
	tx[1] = value;
	memset(rx, 0, sizeof(rx));
	return bcm_spi_transfer((char *)tx, (char *)rx, 2);
}

int bcm_spi_read_reg8(uint8_t address, uint8_t *out) {
	unsigned char tx[2], rx[2];
	tx[0] = address & 0x7F;
	tx[1] = 0x00;
	memset(rx, 0, sizeof(rx));
	int rc = bcm_spi_transfer((char *)tx, (char *)rx, 2);
	if (rc == 0 && out) *out = rx[1];
	return rc;
}

int bcm_spi_write_reg16(uint8_t addr_lsb, uint16_t value) {
	unsigned char tx[3], rx[3];
	tx[0] = 0x80 | (addr_lsb & 0x7F);
	tx[1] = (uint8_t)(value & 0xFF);      // LSB at addr_lsb
	tx[2] = (uint8_t)((value >> 8) & 0xFF); // MSB at addr_lsb+1
	memset(rx, 0, sizeof(rx));
	return bcm_spi_transfer((char *)tx, (char *)rx, 3);
}

int bcm_spi_read_reg16(uint8_t addr_lsb, uint16_t *out) {
	unsigned char tx[3], rx[3];
	tx[0] = addr_lsb & 0x7F;
	tx[1] = 0x00;
	tx[2] = 0x00;
	memset(rx, 0, sizeof(rx));
	int rc = bcm_spi_transfer((char *)tx, (char *)rx, 3);
	if (rc == 0 && out) {
		*out = ((uint16_t)rx[2] << 8) | (uint16_t)rx[1];
	}
	return rc;
}

// High-level API
// writeSpeed packs: data byte0 = (direction<<7) | (speed & 0x7F)
// and writes flags byte1 = (enable & 1) | ((brk & 1) << 1)
// both are written to regs 0x01 (LSB) and 0x02 (MSB) via a 16-bit write
static unsigned current_speed = 0; // 0..127
static unsigned current_dir = 0;
static unsigned current_enable = 0;
static unsigned current_brk = 0;

int writeSpeed(unsigned speed7, unsigned direction, unsigned enable, unsigned brk) {
	if (speed7 > 127 || direction > 1 || enable > 1 || brk > 1) return -1;
	uint8_t byte0 = (uint8_t)((direction & 1) << 7) | (uint8_t)(speed7 & 0x7F);
	uint8_t byte1 = (uint8_t)((enable & 1) | ((brk & 1) << 1));
	uint16_t value = ((uint16_t)byte1 << 8) | (uint16_t)byte0; // MSB: addr+1, LSB: addr
	int rc = bcm_spi_write_reg16(0x01, value);
	if (rc == 0) {
		current_speed = speed7;
		current_dir = direction;
		current_enable = enable;
		current_brk = brk;
	}
	return rc;
}

// readEncoders reads a 16-bit little-endian value at regs 0x10(L) and 0x11(H)
int readEncoders(uint16_t *out) {
	return bcm_spi_read_reg16(0x10, out);
}

static void print_help(void) {
	puts("Commands:\n  read                 Read encoders\n  write S D E          Write speed S(0..127) D(dir 0/1) E(enable 0/1)\n  status               Show device speed/dir/enable/brk\n  quit | exit          Quit\n  help                 Show this help");
}

int main(int argc, char **argv) {
	printf("Initializing bcm2835 SPI (CE=%d) target %u Hz\n", BCM_SPI_CHIP_SELECT, BCM_SPI_TARGET_HZ);
	if (bcm_spi_init(BCM_SPI_CHIP_SELECT, BCM_SPI_TARGET_HZ) != 0) {
		fprintf(stderr, "Failed to initialize SPI (are you root?)\n");
		return 1;
	}

	// Non-interactive shortcut: allow one-shot write
	if (argc >= 5 && strcmp(argv[1], "write") == 0) {
		unsigned s = (unsigned)atoi(argv[2]);
		unsigned d = (unsigned)atoi(argv[3]);
		unsigned e = (unsigned)atoi(argv[4]);
		unsigned brk = 0;
		if (argc >= 6) brk = (unsigned)atoi(argv[5]);
		if (writeSpeed(s, d, e, brk) != 0) {
			fprintf(stderr, "writeSpeed failed\n");
		} else {
			uint8_t v0 = 0, v1 = 0;
			bcm_spi_read_reg8(0x01, &v0);
			bcm_spi_read_reg8(0x02, &v1);
			printf("wrote device speed=0x%02X flags=0x%02X\n", v0, v1);
		}
		bcm_spi_close();
		return 0;
	}

	char line[128];
	print_help();
	while (1) {
		printf("spi> "); fflush(stdout);
		if (!fgets(line, sizeof(line), stdin)) break;
		char cmdstr[32];
		if (sscanf(line, " %31s", cmdstr) != 1) continue;
		if (strcmp(cmdstr, "quit") == 0 || strcmp(cmdstr, "exit") == 0) break;
		if (strcmp(cmdstr, "help") == 0) { print_help(); continue; }
		if (strcmp(cmdstr, "read") == 0) {
			uint16_t enc = 0;
			if (readEncoders(&enc) != 0) fprintf(stderr, "readEncoders failed\n");
			else printf("Encoders = %u (0x%04X)\n", enc, enc);
			continue;
		}
		if (strcmp(cmdstr, "status") == 0) {
			uint8_t v0 = 0, v1 = 0;
			if (bcm_spi_read_reg8(0x01, &v0) != 0) fprintf(stderr, "read speed reg failed\n");
			if (bcm_spi_read_reg8(0x02, &v1) != 0) fprintf(stderr, "read flags reg failed\n");
			unsigned speed = v0 & 0x7F;
			unsigned dir = (v0 >> 7) & 1;
			unsigned enable = v1 & 1;
			unsigned brk = (v1 >> 1) & 1;
			printf("device speed = %u dir=%u enable=%u brk=%u\n", speed, dir, enable, brk);
			continue;
		}
		if (strcmp(cmdstr, "write") == 0) {
			unsigned s, d, e;
			if (sscanf(line, " %*s %u %u %u", &s, &d, &e) < 3) {
				puts("Usage: write <speed(0..127)> <dir(0|1)> <enable(0|1)>");
				continue;
			}
			if (writeSpeed(s, d, e, 0) != 0) {
				fprintf(stderr, "writeSpeed failed (invalid args?)\n");
			} else {
				puts("OK");
				// read back device registers to verify
				uint8_t rv0 = 0, rv1 = 0;
				bcm_spi_read_reg8(0x01, &rv0);
				bcm_spi_read_reg8(0x02, &rv1);
				printf("device now: speed=0x%02X flags=0x%02X\n", rv0, rv1);
			}
			continue;
		}
		puts("Unknown command. Type 'help'.");
	}

	bcm_spi_close();
	return 0;
}

