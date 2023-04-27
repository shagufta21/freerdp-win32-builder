#!/bin/sh

rm -rf $(pwd)/build/$TARGET_ARCH
mkdir -p $(pwd)/build/$TARGET_ARCH
docker build -t win32-builder --build-arg ARCH . # && \
# docker run -it -v $(pwd)/build/$TARGET_ARCH:/out win32-builder /bin/bash && \
# docker run -v $(pwd)/build/$TARGET_ARCH:/out win32-builder bash -c "cp /build/bin/wfreerdp.exe /out/wfreerdp.exe"
docker compose up