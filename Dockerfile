FROM ubuntu:21.04 as builder
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -qq
RUN apt-get install -y xz-utils wget make nasm git ninja-build autoconf automake libtool texinfo help2man yasm gcc

# SETUP WORKSPACE
WORKDIR /tmp
RUN wget https://github.com/mstorsjo/llvm-mingw/releases/download/20211002/llvm-mingw-20211002-msvcrt-ubuntu-18.04-x86_64.tar.xz -O llvm.tar.xz && \
  tar -xf llvm.tar.xz && \
  cp -a /tmp/llvm-mingw-20211002-msvcrt-ubuntu-18.04-x86_64/* /usr/ && \
  rm -rf /tmp/*

RUN mkdir /src
WORKDIR /src

# SETUP TOOLCHAIN
RUN mkdir /src/patch
ARG ARCH
ENV TOOLCHAIN_ARCH=$ARCH

FROM builder as cmake-builder
RUN apt-get install -y cmake
COPY toolchain/cmake /src/toolchain/cmake
ENV TOOLCHAIN_NAME=$TOOLCHAIN_ARCH-w64-mingw32
ENV TOOLCHAIN_CMAKE=/src/toolchain/cmake/$TOOLCHAIN_NAME-toolchain.cmake

FROM builder as meson-builder
RUN apt-get install -y meson
COPY toolchain/meson /src/toolchain/meson
ENV TOOLCHAIN_MESON=/src/toolchain/meson/$TOOLCHAIN_ARCH.txt

# BUILD ZLIB
FROM cmake-builder AS zlib-build
RUN git clone https://github.com/madler/zlib.git /src/zlib
WORKDIR /src/zlib
RUN git fetch; git checkout cacf7f1d4e3d44d871b605da3b647f07d718623f
RUN mkdir /src/zlib/build
WORKDIR /src/zlib/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build -DCMAKE_BUILD_TYPE=Release
RUN cmake --build . -j `nproc`
RUN cmake --install .

# BUILD OPENSSL
FROM cmake-builder AS openssl-build
RUN git clone https://github.com/janbar/openssl-cmake.git /src/openssl
WORKDIR /src/openssl
RUN mkdir /src/openssl/build
WORKDIR /src/openssl/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build \
             -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
RUN cmake --build . -j `nproc`
RUN cmake --install . 

# BUILD OPENH264
FROM meson-builder AS openh264-build
RUN git clone https://github.com/cisco/openh264 /src/openh264
WORKDIR /src/openh264
RUN git fetch; git checkout df32196c72063e326c5b969e1c1a8933a750090f
RUN mkdir /src/openh264/out
WORKDIR /src/openh264/out
RUN meson .. . --cross-file $TOOLCHAIN_MESON --prefix=/build
RUN ninja -j `nproc`
RUN ninja install

# BUILD LIBUSB
FROM cmake-builder AS libusb-build
RUN git clone https://github.com/libusb/libusb.git /src/libusb
WORKDIR /src/libusb
RUN git fetch; git checkout c6a35c56016ea2ab2f19115d2ea1e85e0edae155
RUN mkdir m4; autoreconf -ivf
RUN sed -i.bak "s/-mwin32//g" ./configure
RUN sed -i.bak "s/--add-stdcall-alias//g" ./configure
RUN ./configure --host=$TOOLCHAIN_NAME --prefix=/build
RUN make -j `nproc` && make install

# BUILD FAAC
FROM cmake-builder AS faac-build
RUN git clone https://github.com/knik0/faac.git /src/faac
WORKDIR /src/faac
RUN git fetch; git checkout 78d8e0141600ac006a94ac6fd5601f599fa5b65b
RUN sed -i.bak "s/-Wl,--add-stdcall-alias//g" ./libfaac/Makefile.am
RUN mkdir m4; autoreconf -ivf
RUN sed -i.bak "s/-mwin32//g" ./configure
RUN ./configure --host=$TOOLCHAIN_NAME --prefix=/build
RUN make -j `nproc` && make install

# BUILD FAAD2
FROM cmake-builder AS faad2-build
RUN git clone https://github.com/knik0/faad2.git /src/faad2
WORKDIR /src/faad2
RUN git fetch; git checkout f97f6e933a4ee3cf00b4e1ba4e3a1f05bc9de165
RUN sed -i.bak "s/-Wl,--add-stdcall-alias//g" ./libfaad/Makefile.am
RUN mkdir m4; autoreconf -ivf
RUN sed -i.bak "s/-mwin32//g" ./configure
RUN ./configure --host=$TOOLCHAIN_NAME --prefix=/build
RUN make -j `nproc` && make install

# BUILD OPENCL-HEADERS
FROM cmake-builder AS opencl-headers
RUN git clone https://github.com/KhronosGroup/OpenCL-Headers.git /src/opencl-headers
WORKDIR /src/opencl-headers
RUN git fetch; git checkout 1bb9ec797d14abed6167e3a3d66ede25a702a5c7
RUN mkdir /src/opencl-headers/build
WORKDIR /src/opencl-headers/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build \
             -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF
RUN cmake --build . -j `nproc`
RUN cmake --install . 

# BUILD OPENCL
FROM cmake-builder AS opencl-build
COPY --from=opencl-headers /build /build
RUN git clone https://github.com/KhronosGroup/OpenCL-ICD-Loader.git /src/opencl
WORKDIR /src/opencl
RUN git fetch; git checkout 4e65bd5db0a0a87637fddc081a70d537fc2a9e70
RUN echo 'set_target_properties (OpenCL PROPERTIES PREFIX "")' >> CMakeLists.txt
RUN mkdir /src/opencl/build
WORKDIR /src/opencl/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build \
             -DBUILD_SHARED_LIBS=OFF -DOPENCL_ICD_LOADER_DISABLE_OPENCLON12=ON  \
             -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF \
             -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -I/build/include/" \
             -DCMAKE_CXX_FLAGS="${CMAKE_CXX_FLAGS} -I/build/include/"
RUN cmake --build . -j `nproc`
RUN cmake --install . 

# BUILD FREERDP
FROM cmake-builder AS freerdp-build
RUN git clone https://github.com/alexandru-bagu/FreeRDP.git /src/FreeRDP
COPY --from=zlib-build /build /build
COPY --from=openssl-build /build /build
COPY --from=openh264-build /build /build
COPY --from=libusb-build /build /build
COPY --from=faac-build /build /build
COPY --from=faad2-build /build /build
COPY --from=opencl-build /build /build
RUN mkdir /src/FreeRDP/build
WORKDIR /src/FreeRDP
RUN git fetch; git checkout af366fd09be4906976e2eb9fa04735045c8d575a
COPY patch/mingw32-freerdp.patch /src/patch/
RUN git apply /src/patch/mingw32-freerdp.patch
WORKDIR /src/FreeRDP/build
RUN cmake .. -DCMAKE_TOOLCHAIN_FILE=$TOOLCHAIN_CMAKE -G Ninja -Wno-dev -DCMAKE_INSTALL_PREFIX=/build \
             -DWITH_X11=OFF -DWITH_MEDIA_FOUNDATION=OFF -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release \
             -DWITH_ZLIB=ON -DZLIB_INCLUDE_DIR=/build  \
             -DWITH_OPENH264=ON -DOPENH264_INCLUDE_DIR=/build/include -DOPENH264_LIBRARY=/build/lib/libopenh264.a \
             -DOPENSSL_INCLUDE_DIR=/build/include \
             -DWITH_OPENCL=ON -DOpenCL_INCLUDE_DIR=/build/include -DOpenCL_LIBRARIES=/build/lib/OpenCL.a \
             -DLIBUSB_1_INCLUDE_DIRS=/build/include/libusb-1.0 -DLIBUSB_1_LIBRARIES=/build/lib/libusb-1.0.a \
             -DWITH_WINPR_TOOLS=OFF -DWITH_WIN_CONSOLE=ON -DWITH_PROGRESS_BAR=OFF \
             -DWITH_FAAD2=ON -DFAAD2_INCLUDE_DIR=/build/include -DFAAD2_LIBRARY=/build/lib/libfaad.a \
             -DWITH_FAAC=ON -DFAAC_INCLUDE_DIR=/build/include -DFAAC_LIBRARY=/build/lib/libfaac.a \
             -DWITH_SSE2="$( [[ '$ARCH' == 'x86_64' ]] && printf 'ON'; [[ '$ARCH' == 'i686' ]] && printf 'ON'; [[ '$ARCH' == 'aarch64' ]] && printf 'OFF';  )" \
             -DWITH_NEON="$( [[ '$ARCH' == 'x86_64' ]] && printf 'OFF'; [[ '$ARCH' == 'i686' ]] && printf 'OFF'; [[ '$ARCH' == 'aarch64' ]] && printf 'ON';  )" \
             -DCMAKE_C_FLAGS="${CMAKE_C_FLAGS} -static"
RUN cmake --build . -j `nproc`
RUN cmake --install . 