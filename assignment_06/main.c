#include <stdio.h>
#include <stdint.h>
#include <pthread.h>

#define WIDTH 640
#define HEIGHT 480
#define FRAME_SIZE (WIDTH * HEIGHT * 3 / 2)

#define NUM_BUFFERS 3

/* ============================================================
   FRAME BUFFER
   ============================================================ */

typedef struct
{
    uint8_t data[FRAME_SIZE];

    int ready;
    int being_written;
    int being_read;

} FrameBuffer;

/* ============================================================
   GLOBALS
   ============================================================ */

FrameBuffer buffers[NUM_BUFFERS];

pthread_mutex_t buffer_mutex;
pthread_cond_t frame_cond;

int running = 1;

/* ============================================================
   BUFFER MANAGEMENT
   ============================================================ */

FrameBuffer* get_write_buffer();

FrameBuffer* get_read_buffer();

/* ============================================================
   CAMERA / PRODUCER
   ============================================================ */

void* camera_thread(void *arg);

/* ============================================================
   PROCESSOR / CONSUMER
   ============================================================ */

void* processing_thread(void *arg);

/* ============================================================
   FRAME PROCESSING
   ============================================================ */

void process_frame(uint8_t *frame);

/* ============================================================
   GSTREAMER CALLBACK
   ============================================================ */

// appsink callback:
//
// 1. lock mutex
// 2. get free write buffer
// 3. copy incoming frame into buffer
// 4. mark buffer ready
// 5. signal condition variable
// 6. unlock mutex

// static GstFlowReturn
// on_new_sample(...)

/* ============================================================
   MAIN
   ============================================================ */

int main()
{
    pthread_t camera_tid;
    pthread_t processor_tid;

    /* --------------------------------------------
       INIT THREADING
       -------------------------------------------- */

    pthread_mutex_init(&buffer_mutex, NULL);

    pthread_cond_init(&frame_cond, NULL);

    /* --------------------------------------------
       INIT BUFFER STATES
       -------------------------------------------- */

    for (int i = 0; i < NUM_BUFFERS; i++)
    {
        buffers[i].ready = 0;

        buffers[i].being_written = 0;

        buffers[i].being_read = 0;
    }

    /* --------------------------------------------
       CREATE THREADS
       -------------------------------------------- */

    pthread_create(
        &camera_tid,
        NULL,
        camera_thread,
        NULL);

    pthread_create(
        &processor_tid,
        NULL,
        processing_thread,
        NULL);

    /* --------------------------------------------
       MAIN LOOP
       -------------------------------------------- */

    while (running)
    {
        // application control loop

        // keyboard input
        // statistics
        // UI
        // shutdown handling
    }

    /* --------------------------------------------
       SHUTDOWN
       -------------------------------------------- */

    pthread_join(camera_tid, NULL);

    pthread_join(processor_tid, NULL);

    pthread_mutex_destroy(&buffer_mutex);

    pthread_cond_destroy(&frame_cond);

    return 0;
}