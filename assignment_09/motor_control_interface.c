// motor_controller.c
// Simple SPI CLI controller for FPGA motor driver
// Sends short controlled "blips" to avoid continuous motion

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <linux/spi/spidev.h>
#include <sys/ioctl.h>

#define SPI_DEVICE "/dev/spidev0.0"

// SPI file descriptor
static int spi_fd;

// Low-level SPI send (2-byte packet)
void spi_send_motor_command(uint8_t control_byte, uint8_t speed_percent) {
    uint8_t tx_buffer[2];

    tx_buffer[0] = control_byte;
    tx_buffer[1] = speed_percent;

    write(spi_fd, tx_buffer, 2);
}

 
// Build control byte
// bit7 = enable
// bit6 = direction
// bit5 = breaking
uint8_t build_control_byte(int enable, int direction, int braking) {
    uint8_t control = 0;

    if (enable)   control |= (1 << 7);
    if (direction) control |= (1 << 6);
    if (braking)   control |= (1 << 5);

    return control;
}
 
// Safe short movement ("blip")
void motor_blip(int direction, int speed_percent, int duration_ms) {

    if (speed_percent < 0) speed_percent = 0;
    if (speed_percent > 100) speed_percent = 100;

    if (duration_ms > 200) duration_ms = 200; // safety limit

    uint8_t control = build_control_byte(
        1,              // enable motor
        direction,      // 0 = left, 1 = right
        0               // no braking
    );

    spi_send_motor_command(control, (uint8_t)speed_percent);

    usleep(duration_ms * 1000);

    // stop immediately after movement
    uint8_t stop_control = build_control_byte(0, 0, 0);
    spi_send_motor_command(stop_control, 0);
}
 
// Hard stop
void motor_stop() {
    uint8_t stop_control = build_control_byte(0, 0, 0);
    spi_send_motor_command(stop_control, 0);
}
 
// SPI setup
int setup_spi() {
    spi_fd = open(SPI_DEVICE, O_RDWR);
    if (spi_fd < 0) {
        perror("Failed to open SPI device");
        return -1;
    }

    uint8_t mode = 0;
    uint8_t bits = 8;
    uint32_t speed_hz = 500000;

    ioctl(spi_fd, SPI_IOC_WR_MODE, &mode);
    ioctl(spi_fd, SPI_IOC_WR_BITS_PER_WORD, &bits);
    ioctl(spi_fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed_hz);

    return 0;
}

 
// CLI
int main(int argc, char **argv) {

    if (setup_spi() < 0) {
        return 1;
    }

    if (argc < 2) {
        printf("Usage:\n");
        printf("  %s blip <direction 0/1> <speed 0-100> <ms>\n", argv[0]);
        printf("  %s stop or s\n", argv[0]);
        return 1;
    }

    // ---------------- STOP COMMAND ----------------
    if (strcmp(argv[1], "stop") == 0 || strcmp(argv[1], "s") == 0) {
        motor_stop();
        close(spi_fd);
        return 0;
    }

    // ---------------- BLIP COMMAND ----------------
    if (strcmp(argv[1], "blip") == 0 || strcmp(argv[1], "b") == 0) {

        if (argc != 5) {
            printf("Usage: blip <direction> <speed> <ms>\n");
            return 1;
        }

        int direction = atoi(argv[2]);
        int speed = atoi(argv[3]);
        int duration = atoi(argv[4]);

        motor_blip(direction, speed, duration);

        close(spi_fd);
        return 0;
    }

    printf("Unknown command\n");
    close(spi_fd);
    return 1;
}