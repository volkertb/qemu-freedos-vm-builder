#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2022 Volkert de Buisonjé

BUILD_DIR=./build
DOWNLOAD_DIR=./download
FD_ZIP_FILE=FD13-LiteUSB.zip
FD_DOWNLOAD_URL=https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.3/official/$FD_ZIP_FILE
FD_ZIP_FILE_SHA256=64a934585087ccd91a18c55e20ee01f5f6762be712eeaa5f456be543778f9f7e
FD_DOWNLOAD_PATH=$DOWNLOAD_DIR/$FD_ZIP_FILE
QEMU_MONITOR_LOCAL_PORT=10789
VM_DESIRED_IMAGE_SIZE=100M

mkdir -p $DOWNLOAD_DIR

[ -f "$FD_DOWNLOAD_PATH" ] || (echo "$FD_DOWNLOAD_PATH not found, downloading it." && wget -P $DOWNLOAD_DIR $FD_DOWNLOAD_URL)

sha256sum $FD_DOWNLOAD_PATH | cut -d ' ' -f 1 | grep -xq "^$FD_ZIP_FILE_SHA256$"
if test $? -eq 0; then
  echo "Checksum OK"
else
  echo "Checksum failed. Please delete $DOWNLOAD_DIR/$FD_ZIP_FILE and run this script again."
  exit 1
fi

set -e

mkdir -p $BUILD_DIR
cd $BUILD_DIR
rm -rf ./*
unzip ../$FD_DOWNLOAD_PATH
qemu-img convert -p -f vmdk -O qcow2 FD13LITE.vmdk FD13LITE.qcow2
qemu-img create -f qcow2 freedos.qcow2 $VM_DESIRED_IMAGE_SIZE
qemu-system-i386 \
  -enable-kvm \
  -machine pc \
  -drive aio=io_uring,if=virtio,format=raw,file=FD13LITE.img \
  -drive aio=io_uring,if=virtio,format=qcow2,file=freedos.qcow2 \
  -drive if=none,id=drive-ide0-0-0,readonly=on \
  -monitor tcp:localhost:$QEMU_MONITOR_LOCAL_PORT,server,nowait &

echo Waiting for first boot
sleep 10s

echo Pressing ENTER for English
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo Pressing ENTER for "Yes - Continue with the installation"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ARROW-UP FOR "Yes - Partition drive D:"
echo sendkey up | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER FOR "Yes - Partition drive D:"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

echo Waiting for drive to be partitioned
sleep 7s

echo ENTER FOR "Yes - Please reboot now"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo Waiting for reboot
sleep 10s

echo ENTER for English
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER for "Yes - Continue with the installation"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ARROW-UP FOR "Yes - Please erase and format drive D:"
echo sendkey up | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER FOR "Yes - Please erase and format drive D:"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER for "press a key (skip countdown)"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

echo Wait for "Gathering some information(...)"
sleep 5s

echo ENTER for "US English (Default)"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER for "Plain DOS system"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ARROW-UP FOR "Yes - Please install FreeDOS 1.3"
echo sendkey up | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER FOR "Yes - Please install FreeDOS 1.3"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo Waiting for all files to be copied
sleep 65s # This may need to be tweaked, depending on the speed of the host system

echo ARROW-DOWN FOR "No - Return to DOS"
echo sendkey down | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER FOR "No - Return to DOS"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo Entering "HALT" and pressing ENTER to shut down the VM
echo sendkey h | nc localhost $QEMU_MONITOR_LOCAL_PORT # Halt
echo sendkey a | nc localhost $QEMU_MONITOR_LOCAL_PORT # hAlt
echo sendkey l | nc localhost $QEMU_MONITOR_LOCAL_PORT # haLt
echo sendkey t | nc localhost $QEMU_MONITOR_LOCAL_PORT # halT
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

echo Wait for the installation VM to spin down
sleep 10s

echo FreeDOS VM created. Spinning it up, to you can try it out.
qemu-system-i386 \
  -enable-kvm \
  -machine pc \
  -drive aio=io_uring,if=virtio,format=qcow2,file=freedos.qcow2 \
  -drive if=none,id=drive-ide0-0-0,readonly=on

echo Done.

cd ..
