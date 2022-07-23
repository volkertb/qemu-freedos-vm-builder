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

command -v nc >/dev/null || {
  echo 'nc not found, make sure you have netcat installed.'
  exit 1
}
command -v wget >/dev/null || {
  echo 'wget not found, make sure you have it installed.'
  exit 1
}
command -v qemu-img >/dev/null || {
  echo 'qemu-img not found, make sure you have QEMU installed.'
  exit 1
}
command -v qemu-system-i386 >/dev/null || {
  echo 'qemu-system-i386 not found, make sure you have QEMU installed.'
  exit 1
}

# Workaround for Debian and Ubuntu systems
# With thanks to https://bugzilla.redhat.com/show_bug.cgi?id=754702#c7
if nc -q 2>&1 | grep "requires an argument" >/dev/null; then alias nc="nc -q 0"; fi

qemu_accelerator=tcg
qemu_exec="qemu-system-i386" # qemu-system-i386 is faster for running 16/32 code when TCG (software emulation) is used

# Enable KVM only on Linux systems that support it
grep -E '^flags.*(vmx|svm)' /proc/cpuinfo >/dev/null 2>&1 && {
  echo "Linux system detected with KVM available. Using kvm accelerator for hardware-assisted virtualization."
  qemu_accelerator=kvm
}

# Enable HVF only on macOS systems that support it
sysctl kern.hv_support 2>/dev/null | grep "kern.hv_support: 1" >/dev/null && {
  echo "macOS system detected with HVF available. Using hvf accelerator for hardware-assisted virtualization."
  qemu_accelerator=hvf
  # HVF is apparently not available with qemu-system-i386
  qemu_exec="qemu-system-x86_64"
}

# Enable io_uring only on Linux systems that support it
# With thanks to https://unix.stackexchange.com/a/596284
if grep io_uring_setup /proc/kallsyms >/dev/null 2>&1; then aio_override_prefix="aio=io_uring,"; else aio_override_prefix=""; fi

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

shasum -a 256 $FD_DOWNLOAD_PATH | cut -d ' ' -f 1 | grep -xq "^$FD_ZIP_FILE_SHA256$"
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
qemu-img create -f qcow2 freedos.qcow2 $VM_DESIRED_IMAGE_SIZE
echo "QEMU accelerator to be used: $qemu_accelerator"
$qemu_exec \
  -accel $qemu_accelerator \
  -machine pc \
  -drive "${aio_override_prefix}"if=virtio,format=raw,file=FD13LITE.img \
  -drive "${aio_override_prefix}"if=virtio,format=qcow2,file=freedos.qcow2 \
  -drive if=none,id=drive-ide0-0-0,readonly=on \
  -monitor tcp:localhost:$QEMU_MONITOR_LOCAL_PORT,server,nowait &

qemu_pid=$!
echo "QEMU launched, PID: $qemu_pid"

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

wait_until_text_mode_shows_string "10%" 30 5

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

while kill -0 $qemu_pid >/dev/null 2>&1; do
  echo "Waiting for QEMU process to end.."
  sleep 1
done

echo "FreeDOS VM created. Spinning it up, to you can try it out. Enter the command \"halt\" to shut it down."
$qemu_exec \
  -machine pc \
  -drive "${aio_override_prefix}"if=virtio,format=qcow2,file=freedos.qcow2 \
  -drive if=none,id=drive-ide0-0-0,readonly=on &

rm FD13LITE.*
rm readme.txt

rm /tmp/videodumpbuffer

cd ..

echo "Creation job completed. Have fun! :)"
