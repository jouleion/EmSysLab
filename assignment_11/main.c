// Single-file SPI demo using bcm2835 library with clear comments
// Build (Raspberry Pi):
//   sudo apt install libbcm2835-dev
//   gcc -o spi_demo main.c -l bcm2835
// Run:
//   sudo ./spi_demo [set_speed_percent]

#include <bcm2835.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Choose which chip-select to use (0 for CE0, 1 for CE1)
#define BCM_SPI_CHIP_SELECT 1
// Target SPI clock (approximate). The library chooses the nearest available divider.
#define BCM_SPI_TARGET_HZ 500000

// Pick a suitable clock divider constant from the bcm2835 header based on target hz.
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

// Initialize bcm2835 and configure SPI parameters (mode, bit order, chip select, clock)
// Returns 0 on success, negative on failure.
int bcm_spi_init(unsigned chip_select, unsigned target_hz) {
	if (!bcm2835_init()) {
		fprintf(stderr, "bcm2835_init failed (are you running as root?)\n");
		return -1;
	}
	bcm2835_spi_begin();
	bcm2835_spi_setBitOrder(BCM2835_SPI_BIT_ORDER_MSBFIRST);
	bcm2835_spi_setDataMode(BCM2835_SPI_MODE0);
	bcm2835_spi_chipSelect(chip_select ? BCM2835_SPI_CS1 : BCM2835_SPI_CS0);
	uint16_t div = bcm_choose_clock_divider(target_hz);
	bcm2835_spi_setClockDivider(div);
	return 0;
}

// Shutdown bcm2835 SPI
void bcm_spi_close(void) {
	bcm2835_spi_end();
	bcm2835_close();
}

// Wrapper for bcm2835 full-duplex transfer
// tx and rx buffers must be at least 'count' bytes long.
// Returns 0.
int bcm_spi_transfer(char *tx_buf, char *rx_buf, unsigned count) {
	bcm2835_spi_transfernb(tx_buf, rx_buf, count);
	return 0;
}

// Write single byte to register (command: MSB=1, addr=7 bits)
int bcm_spi_write_reg8(uint8_t address, uint8_t value) {
	unsigned char tx[2], rx[2];
	tx[0] = 0x80 | (address & 0x7F);
	tx[1] = value;
	memset(rx, 0, sizeof(rx));
	return bcm_spi_transfer((char *)tx, (char *)rx, 2);
}

// Read single byte from register (command: MSB=0, addr=7 bits). Reply in rx[1]
int bcm_spi_read_reg8(uint8_t address, uint8_t *out) {
	unsigned char tx[2], rx[2];
	tx[0] = address & 0x7F;
	tx[1] = 0x00; // dummy to clock reply
	memset(rx, 0, sizeof(rx));
	int rc = bcm_spi_transfer((char *)tx, (char *)rx, 2);
	if (rc == 0 && out) *out = rx[1];
	return rc;
}

// Write 16-bit little-endian starting at addr_lsb
int bcm_spi_write_reg16(uint8_t addr_lsb, uint16_t value) {
	unsigned char tx[3], rx[3];
	tx[0] = 0x80 | (addr_lsb & 0x7F);
	tx[1] = (uint8_t)(value & 0xFF);
	tx[2] = (uint8_t)((value >> 8) & 0xFF);
	memset(rx, 0, sizeof(rx));
	return bcm_spi_transfer((char *)tx, (char *)rx, 3);
}

// Read 16-bit little-endian starting at addr_lsb. rx[1]=LSB, rx[2]=MSB
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

// -----------------------------------------------------------------------------
// Example main demonstrating the simple API
// Simple API: three commands exposed as functions
//   write(speed, percent)
//   read(speed)
//   read(encoders)

static void write_speed_cmd(unsigned percent) {
	if (bcm_spi_write_reg8(0x01, (uint8_t)percent) != 0) {
		fprintf(stderr, "Failed to write SPEED\n");
	} else {
		printf("write(speed,%u)\n", percent);
	}
}

static unsigned read_speed_cmd(void) {
	uint8_t v = 0;
	if (bcm_spi_read_reg8(0x01, &v) != 0) {
		fprintf(stderr, "Failed to read SPEED\n");
	} else {
		printf("read(speed) -> %u\n", v);
	}
	return v;
}

static unsigned read_encoders_cmd(void) {
	uint16_t val = 0;
	if (bcm_spi_read_reg16(0x10, &val) != 0) {
		fprintf(stderr, "Failed to read ENCODER\n");
	} else {
		printf("read(encoders) -> %u\n", val);
	}
	return val;
}

int main(int argc, char **argv) {
    // set speed
	unsigned set_speed_percent = 50;

    // if command line speed, use that.
	if (argc > 1) set_speed_percent = atoi(argv[1]);

    // Initialize SPI
	printf("Initializing bcm2835 SPI (CE=%d) target %u Hz\n", BCM_SPI_CHIP_SELECT, BCM_SPI_TARGET_HZ);
	if (bcm_spi_init(BCM_SPI_CHIP_SELECT, BCM_SPI_TARGET_HZ) != 0) {
		return 1;
	}

	// Use the simplified API here as the test script:
	write_speed_cmd(set_speed_percent);
	sleep(1);

    // test read commands.
	read_encoders_cmd();
	read_speed_cmd();

    // close SPI
	bcm_spi_close();
	return 0;
}

