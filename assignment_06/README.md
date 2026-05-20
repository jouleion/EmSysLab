# Compile:

gcc gstream_appsink.c -o gstream_appsink \
$(pkg-config --cflags --libs gstreamer-1.0 gstreamer-app-1.0) \
-pthread


