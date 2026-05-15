#include <gst/gst.h>
#include <glib.h>
#include <gst/app/gstappsink.h>

// v4l2src > image/jpeg, jpegdec > video/raw I420 > appsink
// make this command as a script
//  gst-launch-1.0 -v -e v4l2src device=/dev/video0 !   image/jpeg,width=640,height=480,framerate=30/1 !   jpegdec !   video/x-raw,format=I420 !   appsink location=file.yuv

static gboolean
bus_call (GstBus     *bus,
          GstMessage *msg,
          gpointer    data)
{
  GMainLoop *loop = (GMainLoop *) data;

  switch (GST_MESSAGE_TYPE (msg)) {

    case GST_MESSAGE_EOS:
      g_print ("End of stream\n");
      g_main_loop_quit (loop);
      break;

    case GST_MESSAGE_ERROR: {
      gchar  *debug;
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


static void
on_pad_added (GstElement *element,
              GstPad     *pad,
              gpointer    data)
{
  GstPad *sinkpad;
  GstElement *decoder = (GstElement *) data;
  GstElement *appsink;


  /* We can now link this pad with the vorbis-decoder sink pad */
  g_print ("Dynamic pad created, linking demuxer/decoder\n");

  sinkpad = gst_element_get_static_pad (decoder, "sink");

  gst_pad_link (pad, sinkpad);

  gst_object_unref (sinkpad);
}



int
main (int   argc,
      char *argv[])
{
  GMainLoop *loop;

  // gstreamer elements
  GstElement *pipeline, *source, *jpeg_filter, *decoder, *i420_filter, *appsink; 

  // caps filters for specific file formats.
  GstCaps *jpeg_caps, *i420_caps;

  GstBus *bus;
  guint bus_watch_id;

  /* Initialisation */
  gst_init (&argc, &argv);

  loop = g_main_loop_new (NULL, FALSE);

  // create the elements
  pipeline        = gst_pipeline_new ("video-dump");
  
  /* Create gstreamer elements */
  source          = gst_element_factory_make ("v4l2src",       "video-source");
  jpeg_filter     = gst_element_factory_make ("capsfilter",      "jpeg input");
  decoder         = gst_element_factory_make ("jpegdec",     "jpeg-decoder");
  i420_filter     = gst_element_factory_make ("capsfilter",  "convert-to-i420");
  appsink        = gst_element_factory_make ("appsink", "app-sink");

  /* Set up the caps filters */
  // jpeg, 640x480, 30fps
  jpeg_caps = gst_caps_new_simple ("image/jpeg",
    "width", G_TYPE_INT, 640,
    "height", G_TYPE_INT, 480,
    "framerate", GST_TYPE_FRACTION, 30, 1,
    NULL
  );

  // i420, 640x480, 30fps
  i420_caps = gst_caps_new_simple ("video/x-raw",
    "format", G_TYPE_STRING, "I420",
    "width", G_TYPE_INT, 640,
    "height", G_TYPE_INT, 480,
    NULL
  );

  // set the caps filters to the capsfilter elements
  g_object_set (G_OBJECT (jpeg_filter), "caps", jpeg_caps, NULL);
  g_object_set (G_OBJECT (i420_filter), "caps", i420_caps, NULL);

  // set the source and appsink properties
  g_object_set (G_OBJECT (source), "device", "/dev/video0", NULL);
  //g_object_set (G_OBJECT (appsink), "location", "file1.yuv", NULL);
  g_object_set (G_OBJECT(appsink), "emit-signals", TRUE, "sync", FALSE, NULL);
  g_signal_connect (appsink, "new-sample", G_CALLBACK(on_new_sample), NULL);

  if (!pipeline){
    g_printerr ("Pipeline could not be created. Exiting.\n");
    return -1;
  } if(!source){
    g_printerr ("Source element could not be created. Exiting.\n");
    return -1;
  } if(!jpeg_filter){
    g_printerr ("JPEG filter element could not be created. Exiting.\n");
    return -1;
  } if(!decoder){
    g_printerr ("Decoder element could not be created. Exiting.\n");
    return -1;
  } if(!i420_filter){
    g_printerr ("I420 filter element could not be created. Exiting.\n");
    return -1;
  } if(!appsink){
    g_printerr ("appsink element could not be created. Exiting.\n");
    return -1;
  }

  /* Set up the pipeline */

  /* we set the input filename to the source element */
  // g_object_set (G_OBJECT (source), "location", argv[1], NULL);

  /* we add a message handler */
  bus = gst_pipeline_get_bus (GST_PIPELINE (pipeline));
  bus_watch_id = gst_bus_add_watch (bus, bus_call, loop);
  gst_object_unref (bus);

  /* we add all elements into the pipeline */
  gst_bin_add_many (GST_BIN (pipeline),
                    source, jpeg_filter, decoder, i420_filter, appsink, NULL);

  /* we link the elements together */
  // gst_element_link (source, jpeg);
  gst_element_link_many (source, jpeg_filter, decoder, i420_filter, appsink, NULL);
  // g_signal_connect (jpeg, "pad-added", G_CALLBACK (on_pad_added), decoder);

  /* note that the demuxer will be linked to the decoder dynamically.
     The reason is that Ogg may contain various streams (for example
     audio and video). The source pad(s) will be created at run time,
     by the demuxer when it detects the amount and nature of streams.
     Therefore we connect a callback function which will be executed
     when the "pad-added" is emitted.*/


  /* Set the pipeline to "playing" state*/
  g_print ("Now playing: %s\n", argv[1]);
  gst_element_set_state (pipeline, GST_STATE_PLAYING);


  /* Iterate */
  g_print ("Running...\n");
  g_main_loop_run (loop);


  /* Out of the main loop, clean up nicely */
  g_print ("Returned, stopping playback\n");
  gst_element_set_state (pipeline, GST_STATE_NULL);

  g_print ("Deleting pipeline\n");
  gst_object_unref (GST_OBJECT (pipeline));
  g_source_remove (bus_watch_id);
  g_main_loop_unref (loop);

  return 0;
}