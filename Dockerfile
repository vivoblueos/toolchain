# Copyright (c) 2025 vivo Mobile Communication Co., Ltd.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM ubuntu:24.04

# Install prerequisites.
RUN apt update && \
    apt install -y build-essential ninja-build cmake curl git wget libslirp-dev generate-ninja \
                   python3 python3-pip meson pkg-config libssl-dev libglib2.0-dev flex bison \
                   libfdt-dev clang llvm lld unzip python3-kconfiglib
# Install QEMU.
WORKDIR /tmp/build
RUN wget https://download.qemu.org/qemu-10.0.3.tar.xz
RUN tar xvf qemu-10.0.3.tar.xz
WORKDIR /tmp/build/qemu-10.0.3/build
RUN ../configure --prefix=/blueos-dev/sysroot/usr/local --enable-slirp \
                 --target-list=riscv32-softmmu,riscv64-softmmu,arm-softmmu,aarch64-softmmu && \
    ninja install
# Install Arm toolchains.
WORKDIR /tmp/build
RUN mkdir -p /blueos-dev/sysroot/opt
RUN wget https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/arm-gnu-toolchain-14.3.rel1-x86_64-arm-none-eabi.tar.xz && \
    wget https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-elf.tar.xz && \
    tar xvf arm-gnu-toolchain-14.3.rel1-x86_64-arm-none-eabi.tar.xz -C /blueos-dev/sysroot/opt && \
    tar xvf arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-elf.tar.xz -C /blueos-dev/sysroot/opt && \
    cd /blueos-dev/sysroot/opt && \
    ln -sfn arm-gnu-toolchain-14.3.rel1-x86_64-aarch64-none-elf aarch64-none-elf && \
    ln -sfn arm-gnu-toolchain-14.3.rel1-x86_64-arm-none-eabi arm-none-eabi
ENV PATH="/blueos-dev/sysroot/opt/arm-none-eabi/bin:/blueos-dev/sysroot/opt/aarch64-none-elf/bin:${PATH}"
# Install repo.
WORKDIR /tmp/build
RUN curl -L -o repo https://storage.googleapis.com/git-repo-downloads/repo && chmod a+x repo && mv repo /blueos-dev/sysroot/usr/local/bin
# Build Rust toolchain.
ENV DESTDIR=/blueos-dev/sysroot
RUN git clone --depth=1 --single-branch -b blueos-dev https://github.com/vivoblueos/rust.git && \
    git clone --depth=1 --single-branch -b blueos-dev https://github.com/vivoblueos/cc-rs.git && \
    git clone --depth=1 --single-branch -b blueos-dev https://github.com/vivoblueos/libc.git && \
    cd rust && cp config.blueos.toml config.toml && \
    ./x.py install -i --stage 1 compiler/rustc && \
    ./x.py install -i --stage 1 library/std --target x86_64-unknown-linux-gnu && \
    ./x.py install -i --stage 1 library/std --target aarch64-vivo-blueos-newlib && \
    ./x.py install -i --stage 1 library/std --target thumbv7m-vivo-blueos-newlibeabi && \
    ./x.py install -i --stage 1 library/std --target thumbv8m.main-vivo-blueos-newlibeabihf && \
    ./x.py install -i --stage 1 library/std --target riscv64-vivo-blueos && \
    ./x.py install -i --stage 1 library/std --target riscv32-vivo-blueos && \
    ./x.py install -i --stage 1 library/std --target riscv32imc-vivo-blueos && \
    ./x.py install -i --stage 0 rustfmt && \
    ./x.py install -i --stage 0 rust-analyzer && \
    ./x.py install -i --stage 0 clippy && \
    ./x.py install -i --stage 0 llvm-tools
ENV PATH="/blueos-dev/sysroot/usr/local/bin:${PATH}"
# Clean up.
WORKDIR /blueos-dev
RUN rm -rf /tmp/build
