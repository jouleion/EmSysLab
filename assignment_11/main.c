#include <bcm2835.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

// Try CE1 by default; code will auto-detect CE0/CE1 if nothing is received
#define CS 1
#define SPI_HZ 200000

#define CMD_READ   0x00
#define CMD_WRITE  0x80
#define CMD_LED    0x03 // matches TopEntity LED_COMMAND (0x03)
#define CMD_MOTOR1 0x01

static void spi_init() {
    if (!bcm2835_init()) {
        fprintf(stderr, "bcm2835_init failed\n");
        exit(1);
    }
    bcm2835_spi_begin();
    bcm2835_spi_setBitOrder(BCM2835_SPI_BIT_ORDER_MSBFIRST);
    bcm2835_spi_setDataMode(BCM2835_SPI_MODE0);
    bcm2835_spi_set_speed_hz(SPI_HZ);
    bcm2835_spi_chipSelect(CS ? BCM2835_SPI_CS1 : BCM2835_SPI_CS0);
}

static void xfer(uint8_t *tx, uint8_t *rx, int n) {
    bcm2835_spi_transfernb((char*)tx, (char*)rx, n);
}

static void hexdump(const char *label, uint8_t *buf, int n) {
    printf("%s:", label);
    for (int i = 0; i < n; ++i) printf(" %02X", buf[i]);
    printf("\n");
}

// Parse two incoming bytes that use MSB as flag and 7 data bits each
// Returns 14-bit encoder value (0..16383)
static uint16_t parse_encoder_from_two_bytes(uint8_t b0, uint8_t b1) {
    uint8_t flag0 = (b0 & 0x80) ? 1 : 0;
    uint8_t flag1 = (b1 & 0x80) ? 1 : 0;

    uint16_t part0 = b0 & 0x7F;
    uint16_t part1 = b1 & 0x7F;

    uint16_t val = (part0 << 7) | part1;

    // flags are for debugging SPI framing correctness (should stay stable)
    printf("  flags: b0=%d b1=%d  parts: %03u %03u  encoder=0x%04X (%u)\n",
           flag0, flag1, part0, part1, val, val);

    return val;
}

static void send_led_command(uint8_t on) {
    uint8_t tx[2] = { CMD_LED, (on ? 1 : 0) };
    uint8_t rx[2] = {0,0};
    xfer(tx, rx, 2);
    hexdump("LED TX/RX", tx, 2);
    hexdump("LED RX", rx, 2);
}

int main() {
    spi_init();

    // auto-detect which CE (chip select) is connected to the FPGA
    printf("Probing CE1 first (configured default)...\n");

    int nonzero = 0;

    for (int i = 0; i < 4; ++i) {
        uint8_t tx[2] = { 0x00, 0x00 };
        uint8_t rx[2] = { 0x00, 0x00 };

        xfer(tx, rx, 2);

        printf("probe1 [%d] RX: %02X %02X\n", i, rx[0], rx[1]);

        // if FPGA is alive, it must not return all-zero (even weak misaligned patterns count)
        if (rx[0] != 0 || rx[1] != 0) nonzero = 1;

        usleep(5000);
    }

    if (!nonzero) {
        // try CE0 instead
        printf("No response on CE1, switching to CE0...\n");

        bcm2835_spi_chipSelect(BCM2835_SPI_CS0);

        for (int i = 0; i < 4; ++i) {
            uint8_t tx[2] = { 0x00, 0x00 };
            uint8_t rx[2] = { 0x00, 0x00 };

            xfer(tx, rx, 2);

            printf("probe0 [%d] RX: %02X %02X\n", i, rx[0], rx[1]);

            if (rx[0] != 0 || rx[1] != 0) nonzero = 1;

            usleep(5000);
        }

        if (!nonzero) {
            printf("Warning: still no non-zero response from FPGA.\n");
        }
    } else {
        printf("Device responded on current CE.\n");
    }

    // Read encoder samples a few times and print parsed value
    for (int i = 0; i < 8; ++i) {
        uint8_t tx[2] = { 0x00, 0x00 };
        uint8_t rx[2] = { 0x00, 0x00 };

        xfer(tx, rx, 2);

        printf("read [%d] TX: %02X %02X  RX: %02X %02X\n",
               i, tx[0], tx[1], rx[0], rx[1]);

        // decoder expects 7-bit packing per byte (MSB used as framing flag)
        parse_encoder_from_two_bytes(rx[0], rx[1]);

        usleep(10000);
    }

    // Send LED command as a single two-byte transfer (command + data)
    printf("Sending LED ON\n");
    {
        uint8_t tx[2] = { CMD_LED, 0x01 };
        uint8_t rx[2] = {0,0};

        xfer(tx, rx, 2);

        hexdump("LED TX/RX", tx, 2);
        hexdump("LED RX", rx, 2);
    }

	for(int i = 0; i < 10; ++i) {
	    usleep(200000000);
	}
    printf("Sending LED OFF\n");
    {
        uint8_t tx[2] = { CMD_LED, 0x00 };
        uint8_t rx[2] = {0,0};

        xfer(tx, rx, 2);

        hexdump("LED TX/RX", tx, 2);
        hexdump("LED RX", rx, 2);
    }

    bcm2835_spi_end();
    bcm2835_close();
    return 0;
}