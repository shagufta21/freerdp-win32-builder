#!/bin/sh

docker build -t win32-builder --build-arg ARCH .
docker run -it -v $(pwd)/build/$ARCH:/out win32-builder cp /build/bin/wfreerdp.exe /out/