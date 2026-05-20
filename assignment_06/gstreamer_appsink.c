#include <stdio.h>
#include <stdint.h>
#include <pthread.h>
#include <string.h>
#include <stdbool.h>

#include <gst/gst.h>
#include <gst/app/gstappsink.h>

#define WIDTH 640
#define HEIGHT 480
#define FRAME_SIZE (WIDTH * HEIGHT * 3 / 2)
#define NUM_BUFFERS 3

// FRAME BUFFER
typedef struct {
    uint8_t data[FRAME_SIZE];

    // 0 = free
    // 1 = ready for analysis
    // 2 = being written
    // 3 = being read
    int state;

} FrameBuffer;

// GLOBALS
// buffer
FrameBuffer buffers[NUM_BUFFERS];

FrameBuffer* get_write_buffer();
FrameBuffer* get_read_buffer();

// rotary indexes
int write_index = 0;
int read_index = 0;

// init mutex and condition variable
pthread_mutex_t buffer_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t frame_cond = PTHREAD_COND_INITIALIZER;

// analysis thread
int running = 1;
void* analysis_thread(void *arg);


// Buffer management functions
FrameBuffer* get_write_buffer()
{
    // find a buffer that is not being used.
    // then mark it a ready for writing

    // rotary search through all buffers
    for (int i = 0; i < NUM_BUFFERS; i++)
    {
        int index = (write_index + i) % NUM_BUFFERS;

        // find a free buffer
        if (buffers[index].state == 0)
        {
            // reserve for writing
            buffers[index].state = 2;

            // advance rotary position
            write_index = (index + 1) % NUM_BUFFERS;

            return &buffers[index];
        }
    }

    // if all buffers are busy:
    // overwrite oldest READY frame
    // this prevents appsink from blocking forever

    // ! THIS MIGHT RESULT IN CURRENT ANALYSIS FRAME BEING OVERWRITTEN, rather drop frames until its free again.

    // for (int i = 0; i < NUM_BUFFERS; i++)
    // {
    //     int index = (write_index + i) % NUM_BUFFERS;

    //     if (buffers[index].state == 1)
    //     {
    //         printf("Overwriting old frame in buffer %d\n", index);

    //         buffers[index].state = 2;

    //         write_index = (index + 1) % NUM_BUFFERS;

    //         return &buffers[index];
    //     }
    // }

    // no writable buffer available
    return NULL;
}

FrameBuffer* get_read_buffer()
{
    // find a buffer that is ready for analysis

    for (int i = 0; i < NUM_BUFFERS; i++)
    {
        int index = (read_index + i) % NUM_BUFFERS;

        if (buffers[index].state == 1)
        {
            // reserve for reading
            buffers[index].state = 3;

            // advance rotary position
            read_index = (index + 1) % NUM_BUFFERS;

            return &buffers[index];
        }
    }

    return NULL;
}

// FrameBuffer* set_buffer_free(FrameBuffer* buffer)
// {
//     // mark the buffer as free again

//     buffer->state = 0;

//     return buffer;
// }

// GSTREAMER CALLBACKS
static gboolean
bus_call (GstBus *bus,
          GstMessage *msg,
          gpointer data)
{
    // handle the return messages from the pipeline, such as errors or end of stream.
    GMainLoop *loop = (GMainLoop *) data;

    switch (GST_MESSAGE_TYPE (msg)) {

        case GST_MESSAGE_EOS:
            g_print ("End of stream\n");
            g_main_loop_quit (loop);
            break;

        case GST_MESSAGE_ERROR: {
            gchar *debug;
            GError *error;

            gst_message_parse_error (msg, &error, &debug);
            g_free (debug);

            g_printerr ("Error: %s\n", error->message);
            g_error_free (error);

            g_main_loop_quit (loop);
            break;
        }

        default:
            break;
    }

    return TRUE;
}

bool setup_gstreamer_pipeline(GMainLoop **loop, GstElement **pipeline)
{
    // caps filters for specific file formats.
    GstCaps *jpeg_caps, *i420_caps;

    GstElement *source;
    GstElement *jpeg_filter;
    GstElement *decoder;
    GstElement *i420_filter;
    GstElement *appsink;

    // gstreamer variables
    GstBus *bus;

    // Initialisation
    gst_init(NULL, NULL);

    *loop = g_main_loop_new(NULL, FALSE);

    // create the elements
    *pipeline = gst_pipeline_new("video-dump");

    if (!*pipeline) {
        g_printerr("Failed to create pipeline\n");
        return false;
    }

    /* Create gstreamer elements */
    source = gst_element_factory_make("v4l2src", "video-source");
    jpeg_filter = gst_element_factory_make("capsfilter", "jpeg input");
    decoder = gst_element_factory_make("jpegdec", "jpeg-decoder");
    i420_filter = gst_element_factory_make("capsfilter", "convert-to-i420");
    appsink = gst_element_factory_make("appsink", "app-sink");

    if (!source || !jpeg_filter || !decoder || !i420_filter || !appsink) {
        g_printerr("Failed to create one or more elements\n");
        return false;
    }

    /* Set up the caps filters */
    jpeg_caps = gst_caps_new_simple("image/jpeg",
                                    "width", G_TYPE_INT, 640,
                                    "height", G_TYPE_INT, 480,
                                    "framerate", GST_TYPE_FRACTION, 30, 1,
                                    NULL);

    i420_caps = gst_caps_new_simple("video/x-raw",
                                    "format", G_TYPE_STRING, "I420",
                                    "width", G_TYPE_INT, 640,
                                    "height", G_TYPE_INT, 480,
                                    NULL);

    g_object_set(G_OBJECT(jpeg_filter), "caps", jpeg_caps, NULL);
    g_object_set(G_OBJECT(i420_filter), "caps", i420_caps, NULL);

    g_object_set(G_OBJECT(source), "device", "/dev/video0", NULL);

    g_object_set(G_OBJECT(appsink),
        "emit-signals", TRUE,
        "sync", FALSE,

        // appsink queue settings
        // drop old frames if application is too slow
        "max-buffers", 1,
        "drop", TRUE,

        NULL
    );

    GstCaps *caps = gst_caps_new_simple(
        "video/x-raw",
        "format", G_TYPE_STRING, "I420",
        "width", G_TYPE_INT, 640,
        "height", G_TYPE_INT, 480,
        NULL
    );

    g_object_set(appsink, "caps", caps, NULL);
    gst_caps_unref(caps);

    g_signal_connect(appsink, "new-sample", G_CALLBACK(on_new_sample), NULL);

    /* we add a message handler */
    bus = gst_pipeline_get_bus(GST_PIPELINE(*pipeline));
    gst_bus_add_watch(bus, bus_call, *loop);
    gst_object_unref(bus);

    /* we add all elements into the pipeline */
    gst_bin_add_many(
        GST_BIN(*pipeline),
        source,
        jpeg_filter,
        decoder,
        i420_filter,
        appsink,
        NULL
    );

    if (!gst_element_link_many(
            source,
            jpeg_filter,
            decoder,
            i420_filter,
            appsink,
            NULL))
    {
        g_printerr("Failed to link pipeline\n");
        return false;
    }

    return true;
}

static GstFlowReturn
on_new_sample(GstElement *sink, gpointer data)
{
    // Load new sample into a free buffer slot in the FrameBuffer array.
    // mapping is used to acces the buffer data.
    // handle errors, and unreference the sample when done to prevent memory leaks.

    GstSample *sample;
    GstBuffer *buffer;
    GstMapInfo map;

    // get the new sample
    sample = gst_app_sink_pull_sample(GST_APP_SINK(sink));

    if (!sample) {
        g_printerr("Could not pull sample from appsink\n");
        return GST_FLOW_ERROR;
    }

    // load sample data into the buffer
    buffer = gst_sample_get_buffer(sample);

    // get the buffer data via mapping (this works by mapping the buffer into this applications memory space)
    if (gst_buffer_map(buffer, &map, GST_MAP_READ)) {

        pthread_mutex_lock(&buffer_mutex);

        // get a write buffer
        FrameBuffer *write_buffer = get_write_buffer();

        if (write_buffer) {

            // copy the data into the buffer
            memcpy(write_buffer->data, map.data, FRAME_SIZE);

            // mark buffer as ready for analysis
            write_buffer->state = 1;

            // wake analysis thread
            pthread_cond_signal(&frame_cond);
        }
        else {
            g_printerr("No writable buffer available\n");
        }

        pthread_mutex_unlock(&buffer_mutex);

        gst_buffer_unmap(buffer, &map);
    }
    else {
        g_printerr("Could not map buffer\n");
    }

    // unreference the sample (this will free the sample and its buffer if no other references exist)
    gst_sample_unref(sample);

    return GST_FLOW_OK;
}

int analyze_frame(uint8_t *data, size_t size)
{
    // loop over all pixels
    // convert data to YUV values
    // determine color value using the YUV threshold values
    // count number of green pixels

    int counter = 0;

    // load the data into Y, U and V planes.
    uint8_t *Y = data;
    uint8_t *U = data + WIDTH * HEIGHT;
    uint8_t *V = data + WIDTH *HEIGHT + (WIDTH * HEIGHT / 4);

    for (int y = 0; y < HEIGHT; y++) {

        for (int x = 0; x < WIDTH; x++) {

            int uv_index =
                (y / 2) * (WIDTH / 2) +
                (x / 2);

            uint8_t u_val = U[uv_index];
            uint8_t v_val = V[uv_index];

            if (u_val < 100 && v_val < 100)
            {
                counter++;
            }
        }
    }

    return counter;
}

void* analysis_thread(void *arg)
{
    while (running)
    {
        // wait for frame data

        pthread_mutex_lock(&buffer_mutex);

        FrameBuffer *read_buffer = NULL;

        // wait until a frame exists
        while ((read_buffer = get_read_buffer()) == NULL && running)
        {
            pthread_cond_wait(&frame_cond, &buffer_mutex);
        }
        // if loop was stopped, exit thread
        if (!running)
        {
            pthread_mutex_unlock(&buffer_mutex);
            break;
        }
        pthread_mutex_unlock(&buffer_mutex);

        // ANALYZE THE FRAME
        int num_green_pixels = analyze_frame(read_buffer->data, FRAME_SIZE);
        printf("Frame analyzed, number of green pixels: %d\n", num_green_pixels);

        
        // mark buffer free again
        pthread_mutex_lock(&buffer_mutex);
        read_buffer->state = 0;
        pthread_mutex_unlock(&buffer_mutex);
    }

    return NULL;
}

int main()
{
    printf("Starting green pixel detection application\n");

    // Initialize buffers
    for (int i = 0; i < NUM_BUFFERS; i++) {
        buffers[i].state = 0;
    }

    // The other thread that is used to process the frames data.
    pthread_t analysis_tid;
    pthread_mutex_init(&buffer_mutex, NULL);
    pthread_cond_init(&frame_cond, NULL);
    running = 1;
    // start analysis thread
    pthread_create(
        &analysis_tid,
        NULL,
        analysis_thread,
        NULL
    );

    // Gstreamer variables
    GMainLoop *loop;
    GstElement *pipeline;

    // setup pipeline
    bool success = setup_gstreamer_pipeline(&loop, &pipeline);
    if(!success) {
        g_printerr("Failed to set up gstreamer pipeline. Exiting.\n");
        return -1;
    }
    else {
        g_print("Gstreamer pipeline set up successfully\n");
    }

    // start pipeline
    gst_element_set_state(pipeline, GST_STATE_PLAYING);

    // MAIN LOOP (blocks here)
    g_main_loop_run(loop);

    // shutdown
    running = 0;

    pthread_cond_broadcast(&frame_cond);

    pthread_join(analysis_tid, NULL);

    gst_element_set_state(pipeline, GST_STATE_NULL);
    gst_object_unref(pipeline);

    pthread_mutex_destroy(&buffer_mutex);
    pthread_cond_destroy(&frame_cond);

    return 0;
}