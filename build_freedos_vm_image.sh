#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Copyright 2022 Volkert de Buisonjé
#
# NOTE: If you're running this on something other than Linux, or you don't have KVM available in your Linux environment,
#       you'll need to remove the parameter `-enable-kvm` from the `qemu-system-i386` commands.
#

BUILD_DIR=./build
DOWNLOAD_DIR=./download
FD_ZIP_FILE=FD13-LiteUSB.zip
FD_DOWNLOAD_URL=https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.3/official/$FD_ZIP_FILE
FD_ZIP_FILE_SHA256=64a934585087ccd91a18c55e20ee01f5f6762be712eeaa5f456be543778f9f7e
FD_DOWNLOAD_PATH=$DOWNLOAD_DIR/$FD_ZIP_FILE
QEMU_MONITOR_LOCAL_PORT=10789
VM_DESIRED_IMAGE_SIZE=100M

wait_until_text_mode_shows_string() {
  string_to_wait_for=$1
  number_of_retries=$2
  delay_after_each_retry_in_seconds=$3

  echo "Waiting for text mode video buffer to showing string ${string_to_wait_for}"

  # With thanks to https://stackoverflow.com/a/34434973 for figuring out a POSIX-compliant while-loop
  j=0
  while [ $j -le "${number_of_retries}" ]; do
    j=$((j + 1))
    echo "Checking if text mode video buffer is showing string ${string_to_wait_for}, attempt $j"

    echo "pmemsave 0xb8000 4000 \"/tmp/videodumpbuffer\"" | nc localhost $QEMU_MONITOR_LOCAL_PORT &

    # With thanks to https://stackoverflow.com/a/58837696 (for stripping out every second byte from the video dump)
    (LC_ALL=C awk -F "" '{
            for(i=1;i<=NF;i++)                # iterate all chars
                if(i%2!=p)                    # output every other char
                    printf $i
            if(p=((p&&NF%2)||(!p&&!(NF%2))))  # xor
                printf "\n"                   # handle newlines, all but the last
        }' /tmp/videodumpbuffer | grep "$string_to_wait_for") && return 0

    sleep "${delay_after_each_retry_in_seconds}"s
  done
  echo "Timeout after waiting too long for text mode video buffer to show string ${string_to_wait_for}" >/dev/stderr
  return 1
}

[ ! -e /tmp/videodumpbuffer ] && mkfifo /tmp/videodumpbuffer

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

echo Waiting for QEMU instance to spin up
# With thanks to https://stackoverflow.com/a/27601038
while ! nc -z localhost $QEMU_MONITOR_LOCAL_PORT; do
  sleep 0.1 # wait for 1/10 of the second before check again
done
echo "QEMU monitor port is listening."

wait_until_text_mode_shows_string "What is your preferred language?" 10 1

echo Pressing ENTER for English
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

wait_until_text_mode_shows_string "Do you want to proceed?" 5 1

echo Pressing ENTER for "Yes - Continue with the installation"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

wait_until_text_mode_shows_string "Yes - Partition drive D:" 5 1

echo ARROW-UP FOR "Yes - Partition drive D:"
echo sendkey up | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER FOR "Yes - Partition drive D:"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

echo Waiting for drive to be partitioned
wait_until_text_mode_shows_string "Yes - Please reboot now" 10 1

echo ENTER FOR "Yes - Please reboot now"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

echo Waiting for reboot
wait_until_text_mode_shows_string "What is your preferred language?" 10 1

echo ENTER for English
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

wait_until_text_mode_shows_string "Yes - Continue with the installation" 5 1

echo ENTER for "Yes - Continue with the installation"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

wait_until_text_mode_shows_string "Yes - Please erase and format drive D:" 5 1

echo ARROW-UP FOR "Yes - Please erase and format drive D:"
echo sendkey up | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER FOR "Yes - Please erase and format drive D:"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

wait_until_text_mode_shows_string "Press a key..." 5 1

echo ENTER for "press a key (skip countdown)"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

echo Wait for "Gathering some information(...)"
wait_until_text_mode_shows_string "Please select your keyboard layout." 5 1

echo ENTER for "US English (Default)"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

wait_until_text_mode_shows_string "Plain DOS system" 5 1

echo ENTER for "Plain DOS system"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

wait_until_text_mode_shows_string "Yes - Please install FreeDOS" 5 1

echo ARROW-UP FOR "Yes - Please install FreeDOS"
echo sendkey up | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER FOR "Yes - Please install FreeDOS"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

echo Waiting for all files to be copied
wait_until_text_mode_shows_string "Do you want to reboot now?" 30 5

echo ARROW-DOWN FOR "No  - Return to DOS"
echo sendkey down | nc localhost $QEMU_MONITOR_LOCAL_PORT

sleep 1s

echo ENTER FOR "No  - Return to DOS"
echo sendkey ret | nc localhost $QEMU_MONITOR_LOCAL_PORT

# We need four backslashes for escaping a single backslash. See https://stackoverflow.com/a/38584332
wait_until_text_mode_shows_string ":\\\\>" 5 1

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

rm /tmp/videodumpbuffer
