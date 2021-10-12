#!/bin/sh

rm -rf $(pwd)/build/$ARCH
mkdir -p $(pwd)/build/$ARCH
docker build -t win32-builder --build-arg ARCH . && \
#docker run -it -v $(pwd)/build/$ARCH:/out win32-builder /bin/bash
docker run -it -v $(pwd)/build/$ARCH:/out win32-builder bash -c "cp /build/bin/wfreerdp.exe /out/ && cp /build/bin/libopenh264.dll /out/"
cp msvcr120/bin/$ARCH/msvcr120.dll $(pwd)/build/$ARCH