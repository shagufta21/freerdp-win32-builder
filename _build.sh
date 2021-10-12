#!/bin/sh

docker build -t win32-builder --build-arg ARCH . && \
#docker run -it -v $(pwd)/build/$ARCH:/out win32-builder /bin/bash
docker run -it -v $(pwd)/build/$ARCH:/out win32-builder bash -c "cp /build/bin/wfreerdp.exe /out/ && cp /build/bin/libopenh264.dll /out/"