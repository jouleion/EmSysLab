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
typedef struct
{
    uint8_t data[FRAME_SIZE];

    int ready;
    int being_written;
    int being_read;

} FrameBuffer;

// GLOBALS
// buffer
FrameBuffer buffers[NUM_BUFFERS];
FrameBuffer* get_write_buffer();
FrameBuffer* get_read_buffer();

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

	// lock all buffer access
    pthread_mutex_lock(&buffer_mutex);

    for (int i = 0; i < NUM_BUFFERS; i++)
    {
		// find a buffer that is not ready yet, and not being written to.
        if (!buffers[i].ready && !buffers[i].being_written)
        {
			// update the being written to flag.
            buffers[i].being_written = 1;

			// unlock the full buffer access and return the pointer to the buffer.
            pthread_mutex_unlock(&buffer_mutex);
            return &buffers[i];

			// this return makes sure we only return the first buffer.
        }
    }
	// if non found, unlock and return null.
    pthread_mutex_unlock(&buffer_mutex);
    return NULL;
}

FrameBuffer* get_read_buffer()
{
	// find a buffer that is ready for analysis, and not being read.
	// then mark it as being read.

	// lock all buffer access
	pthread_mutex_lock(&buffer_mutex);

	for (int i = 0; i < NUM_BUFFERS; i++)
	{
		// find a buffer that is ready, and not being read.
		if (buffers[i].ready && !buffers[i].being_read)
		{
			// update the being read flag.
			buffers[i].being_read = 1;

			// unlock the full buffer access and return the pointer to the buffer.
			pthread_mutex_unlock(&buffer_mutex);
			return &buffers[i];

			// this return makes sure we only return the first buffer.
		}
	}
	// if non found, unlock and return null.
	pthread_mutex_unlock(&buffer_mutex);
	return NULL;
}

// GSTREAMER CALLBACK
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

		// get a write buffer
		pthread_mutex_lock(&buffer_mutex);
		FrameBuffer *write_buffer = get_write_buffer();

		if (write_buffer) {

			// copy the data into the buffer
			memcpy(write_buffer->data, map.data, FRAME_SIZE);

			// mark the buffer as ready
			write_buffer->ready = 1;

			pthread_cond_signal(&frame_cond);
		}
		else {
			g_printerr("No free write buffer available\n");
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

bool setup_gstreamer_pipeline(GMainLoop **loop, GstElement **pipeline, GstElement **source, GstElement **jpeg_filter, GstElement **decoder, GstElement **i420_filter, GstElement **appsink){
	// caps filters for specific file formats.
	GstCaps *jpeg_caps, *i420_caps;

	// gstreamer variables
	GstBus *bus;
	guint bus_watch_id;

	/* Initialisation */
	gst_init (NULL, NULL);

	*loop = g_main_loop_new (NULL, FALSE);

	// create the elements
	*pipeline        = gst_pipeline_new ("video-dump");
	
	/* Create gstreamer elements */
	*source          = gst_element_factory_make ("v4l2src",       "video-source");
	*jpeg_filter     = gst_element_factory_make ("capsfilter",      "jpeg input");
	*decoder         = gst_element_factory_make ("jpegdec",     "jpeg-decoder");
	*i420_filter     = gst_element_factory_make ("capsfilter",  "convert-to-i420");
	*appsink         = gst_element_factory_make ("appsink", "app-sink");

	/* Set up the caps filters */
	jpeg_caps = gst_caps_new_simple ("image/jpeg",
		"width", G_TYPE_INT, 640,
		"height", G_TYPE_INT, 480,
		"framerate", GST_TYPE_FRACTION, 30, 1,
		NULL
	);

	i420_caps = gst_caps_new_simple ("video/x-raw",
		"format", G_TYPE_STRING, "I420",
		"width", G_TYPE_INT, 640,
		"height", G_TYPE_INT, 480,
		NULL
	);

	g_object_set (G_OBJECT (jpeg_filter), "caps", jpeg_caps, NULL);
	g_object_set (G_OBJECT (i420_filter), "caps", i420_caps, NULL);

	g_object_set (G_OBJECT (source), "device", "/dev/video0", NULL);
	g_object_set (G_OBJECT(appsink), "emit-signals", TRUE, "sync", FALSE, NULL);

	g_signal_connect (appsink, "new-sample", G_CALLBACK(on_new_sample), NULL);

	/* we add a message handler */
	bus = gst_pipeline_get_bus (GST_PIPELINE (pipeline));
	bus_watch_id = gst_bus_add_watch (bus, bus_call, loop);
	gst_object_unref (bus);

	/* we add all elements into the pipeline */
	gst_bin_add_many (GST_BIN (pipeline),
						source, jpeg_filter, decoder, i420_filter, appsink, NULL);

	gst_element_link_many (source, jpeg_filter, decoder, i420_filter, appsink, NULL);

	return true;
}

int analyze_frame(uint8_t *data, size_t size){
	// loop over all pixels
	// convert data to YUV values
	// determine color value using the YUV threshold values
	// count number of green pixels
	int counter = 0;

	// load the data into Y, U and V planes.
	uint8_t *Y = data;
	uint8_t *U = data + FRAME_WIDTH * FRAME_HEIGHT;
	uint8_t *V = data + FRAME_WIDTH * FRAME_HEIGHT + (FRAME_WIDTH * FRAME_HEIGHT / 4);

	for (int y = 0; y < FRAME_HEIGHT; y++) {
		for (int x = 0; x < FRAME_WIDTH; x++) {
			int y_index = y * FRAME_WIDTH + x;

			int uv_index =
				(y / 2) * (FRAME_WIDTH / 2) +
				(x / 2);

			uint8_t y_val = Y[y_index];
			uint8_t u_val = U[uv_index];
			uint8_t v_val = V[uv_index];

			// if (v_val > 200 && u_val < 120)
			// {
			// 	// red
			// }

			// if (u_val > 200 && v_val < 150)
			// {
			// 	// blue
			// }

			if (u_val < 100 && v_val < 100)
			{
				// green
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
		// check if there is a buffer that is ready for processing. (written to, and free)
		pthread_mutex_lock(&buffer_mutex);
		FrameBuffer *read_buffer = get_read_buffer();

		// check if we got a buffer, if not wait for a signal that a new frame is ready.
		if (!read_buffer) {
			// wait for a ready signal. (unlocks the mutex while waiting, and re-locks it when signaled)
			pthread_cond_wait(&frame_cond, &buffer_mutex);

		} else {
			// mark the buffer as being read
			read_buffer->being_read = 1;
			pthread_mutex_unlock(&buffer_mutex);

			// ANALYZE THE FRAME
			int num_green_pixels = analyze_frame(read_buffer->data, FRAME_SIZE);
			
			// after processing, mark the buffer as free again
			pthread_mutex_lock(&buffer_mutex);
			read_buffer->ready = 0;
			read_buffer->being_read = 0;
			pthread_mutex_unlock(&buffer_mutex);

			// after unlocking the buffer, then print the results. (minimize the time in the critical section)
			printf("Number of green pixels: %d\n", num_green_pixels);
		}
	}
	return NULL;
}

int main()
{
	// Initialize buffers
	for (int i = 0; i < NUM_BUFFERS; i++) {
		buffers[i].ready = 0;
		buffers[i].being_written = 0;
		buffers[i].being_read = 0;
	}

	// The other thread that is used to process the frames data.
	pthread_t analysis_tid;
	pthread_mutex_init(&buffer_mutex, NULL);
	pthread_cond_init(&frame_cond, NULL);

	// start analysis thread
	pthread_create(
		&analysis_tid,
		NULL,
		analysis_thread,
		NULL);

	// Gstreamer variables
	GMainLoop *loop;
	GstElement *pipeline, *source, *jpeg_filter, *decoder, *i420_filter, *appsink; 

	// setup pipeline
	bool success = setup_gstreamer_pipeline(
		&loop, &pipeline,
		&source, &jpeg_filter,
		&decoder, &i420_filter,
		&appsink);

	if(!success){
		g_printerr("Failed to set up gstreamer pipeline. Exiting.\n");
		return -1;
	}

	// start pipeline
	gst_element_set_state(pipeline, GST_STATE_PLAYING);

	// MAIN LOOP (blocks here)
	g_main_loop_run(loop);

	// shutdown
	running = 0;

	pthread_join(analysis_tid, NULL);

	gst_element_set_state(pipeline, GST_STATE_NULL);
	gst_object_unref(pipeline);

	pthread_mutex_destroy(&buffer_mutex);
	pthread_cond_destroy(&frame_cond);

	return 0;
}