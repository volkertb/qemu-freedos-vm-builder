# FreeDOS VM builder

## What is this for?

I wanted a convenience script that automatically builds a ready-to-use throwaway FreeDOS VM using the FreeDOS lite (USB)
installer image. So I made one. Hopefully it will be useful to others as well. :)

## Prerequisites

* a recent GNU/Linux OS with KVM enabled
* QEMU
* wget
* unzip

## How to use

Just run the script:

```shell
./build-qemu-freedos-vm-img.py
```

Some variables, notably the desired target VM size, can be tweaked as desired at the top of the script.

## Possible issues

If you are running this script on a slower PC, you may have to tweak the durations of the individual `sleep` commands.

## Download URLs

* FD13-LiteUSB.zip (the script will automatically download this file to the `download` subfolder if it doesn't find it
  there)
  * URL: https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.3/official/FD13-LiteUSB.zip 
  * SHA-256 checksum: 64a934585087ccd91a18c55e20ee01f5f6762be712eeaa5f456be543778f9f7e