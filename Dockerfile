# SETUP WORKSPACE
FROM ubuntu:21.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update
RUN apt -y install cmake mingw-w64 git ninja-build autoconf automake libtool

RUN mkdir /src
WORKDIR /src

# CHECKOUT REPOSITORIES
RUN git clone https://github.com/madler/zlib.git /src/zlib
RUN git clone https://github.com/janbar/openssl-cmake.git /src/openssl
RUN git clone https://github.com/libusb/libusb.git /src/libusb
RUN git clone https://github.com/FreeRDP/FreeRDP.git /src/FreeRDP

# SETUP ENVIRONMENT
COPY toolchain/ /src/toolchain
COPY patch/ /src/patch
ENV TOOLCHAIN_ARCH=i686
ENV TOOLCHAIN_NAME=$TOOLCHAIN_ARCH-w64-mingw32
ENV TOOLCHAIN_CMAKE=/src/toolchain/win-$TOOLCHAIN_ARCH-toolchain.cmake

# BUILD ZLIB
WORKDIR /src/zlib
RUN git fetch; git checkout cacf7f1d4e3d44d871b605da3b647f07d718623f
RUN mkdir /src/zlib/build
WORKDIR /src/zlib/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build . -j `nproc`
RUN cmake --install .

# BUILD LIBUSB
WORKDIR /src/libusb
RUN git fetch; git checkout c6a35c56016ea2ab2f19115d2ea1e85e0edae155
RUN ./bootstrap.sh
RUN ./configure --host=$TOOLCHAIN_NAME  --prefix=/build
RUN make -j `nproc` && make install

# BUILD OPENSSL
WORKDIR /src/openssl
RUN mkdir /src/openssl/build
WORKDIR /src/openssl/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build \
             -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
             -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -Wall -Wextra -w -DWINVER=0x0600 -D_WIN32_WINNT=0x0600 " \
             -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -Wall -Wextra -w -DWINVER=0x0600 -D_WIN32_WINNT=0x0600 " 
RUN cmake --build . -j `nproc`
RUN cmake --install . 

# # BUILD FREERDP
RUN mkdir /src/FreeRDP/build
WORKDIR /src/FreeRDP
RUN git fetch; git checkout 96cf17a45b2c1070f681272edc0ef87826f51b30
#RUN git apply /src/patch/mingw32-freerdp.patch
#WORKDIR /src/FreeRDP/build
# RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build -DWITH_X11=OFF \
#              -DWITH_ZLIB=ON -DZLIB_INCLUDE_DIR=/build \
#              -DOPENSSL_INCLUDE_DIR=/build/include -DLIBUSB_1_INCLUDE_DIR=/build/include/libusb-1.0 \
#              -DBUILD_SHARED_LIBS=ON \
#              -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -Wall -Wextra -w -DWINVER=0x0600 -D_WIN32_WINNT=0x0600 "
# RUN cmake --build . -j `nproc`