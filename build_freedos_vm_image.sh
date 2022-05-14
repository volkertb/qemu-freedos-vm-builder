#!/bin/sh

BUILD_DIR=./build
FD_ZIP_FILE=FD13-LiteUSB.zip
FD_DOWNLOAD_URL=https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.3/official/$FD_ZIP_FILE
FD_ZIP_FILE_SHA256=64a934585087ccd91a18c55e20ee01f5f6762be712eeaa5f456be543778f9f7e
FD_DOWNLOAD_PATH=$BUILD_DIR/$FD_ZIP_FILE

mkdir -p $BUILD_DIR

[ -f "$FD_DOWNLOAD_PATH" ] || (echo "$FD_DOWNLOAD_PATH not found, downloading it." && wget -P $BUILD_DIR $FD_DOWNLOAD_URL)

sha256sum $FD_DOWNLOAD_PATH | cut -d ' ' -f 1 | grep -xq "^$FD_ZIP_FILE_SHA256$"
if test $? -eq 0; then
  echo "Checksum OK"
else
  echo "Checksum failed. Please delete $BUILD_DIR/$FD_ZIP_FILE and run this script again."
  exit 1
fi

set -e

echo Done.

cd ..
