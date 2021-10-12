# SETUP WORKSPACE
FROM archlinux:latest
RUN yes | pacman -Syu
RUN yes | pacman -S which make cmake git ninja autoconf automake libtool texinfo help2man
RUN pacman -S mingw-w64 --noconfirm

RUN mkdir /src
WORKDIR /src

# CHECKOUT REPOSITORIES
RUN git clone https://github.com/madler/zlib.git /src/zlib
RUN git clone https://github.com/janbar/openssl-cmake.git /src/openssl
RUN git clone https://github.com/libusb/libusb.git /src/libusb
RUN git clone https://github.com/alexandru-bagu/FreeRDP.git /src/FreeRDP

# SETUP TOOLCHAIN
COPY toolchain/ /src/toolchain
ENV TOOLCHAIN_ARCH=x86_64
ENV TOOLCHAIN_NAME=$TOOLCHAIN_ARCH-w64-mingw32
ENV TOOLCHAIN_CMAKE=/src/toolchain/$TOOLCHAIN_NAME-toolchain.cmake

# BUILD ZLIB
WORKDIR /src/zlib
RUN git fetch; git checkout cacf7f1d4e3d44d871b605da3b647f07d718623f
RUN mkdir /src/zlib/build
WORKDIR /src/zlib/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build . -j `nproc`
RUN cmake --install .

# BUILD OPENSSL
WORKDIR /src/openssl
RUN mkdir /src/openssl/build
WORKDIR /src/openssl/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build \
             -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
RUN cmake --build . -j `nproc`
RUN cmake --install . 

# BUILD LIBUSB
WORKDIR /src/libusb
RUN git fetch; git checkout c6a35c56016ea2ab2f19115d2ea1e85e0edae155
RUN mkdir m4; autoreconf -ivf
RUN ./configure --host=$TOOLCHAIN_NAME --prefix=/build
RUN make -j `nproc` && make install

# BUILD FREERDP
COPY patch/ /src/patch
RUN mkdir /src/FreeRDP/build
WORKDIR /src/FreeRDP
RUN git fetch; git checkout 39cffae61aad012710de4710ff33eeedaba7f5da
RUN git apply /src/patch/mingw32-freerdp.patch
WORKDIR /src/FreeRDP/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build -DWITH_X11=OFF \
             -DWITH_ZLIB=ON -DZLIB_INCLUDE_DIR=/build -DBUILD_SHARED_LIBS=OFF \
             -DOPENSSL_INCLUDE_DIR=/build/include \
             -DLIBUSB_1_INCLUDE_DIRS=/build/include/libusb-1.0 \
             -DLIBUSB_1_LIBRARIES=/build/lib/libusb-1.0.a \
             -DWITH_WINPR_TOOLS=OFF -DWITH_WIN_CONSOLE=ON \
             -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -static"
RUN cmake --build . -j `nproc`
RUN cmake --install . 