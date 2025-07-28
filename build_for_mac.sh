#!/bin/bash

set -x
# Default values
SYSROOT_PATH=""
SHOW_HELP=false
SRC_PATH=$(pwd)

# Function to display help message
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --sysroot <path>    Specify the path for sysroot directory"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --sysroot /path/to/sysroot"
    echo "  $0 --help"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sysroot)
            if [[ -n "$2" && "$2" != -* ]]; then
                SYSROOT_PATH="$2"
                shift 2
            else
                echo "Error: --sysroot requires a path argument"
                exit 1
            fi
            ;;
        --help)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Error: Unknown option $1"
            show_help
            exit 1
            ;;
    esac
done

# Show help if requested
if [[ "$SHOW_HELP" == true ]]; then
    show_help
    exit 0
fi

# Check if sysroot path is provided
if [[ -z "$SYSROOT_PATH" ]]; then
    echo "Error: --sysroot <path> is required"
    show_help
    exit 1
fi

# Create sysroot directory if it doesn't exist
if [[ ! -d "$SYSROOT_PATH" ]]; then
    echo "Creating sysroot directory: $SYSROOT_PATH"
    mkdir -p $SYSROOT_PATH
fi

# Convert to absolute path
if command -v realpath >/dev/null 2>&1; then
    SYSROOT_PATH=$(realpath "$SYSROOT_PATH")
else
    # Fallback for systems without realpath
    SYSROOT_PATH=$(readlink -f "$SYSROOT_PATH" 2>/dev/null || echo "$(cd "$(dirname "$SYSROOT_PATH")" && pwd)/$(basename "$SYSROOT_PATH")")
fi

echo "Sysroot path: $SYSROOT_PATH"
OPT_PATH="$SYSROOT_PATH/opt"
mkdir -p $OPT_PATH/bin

# install tools
brew install coreutils llvm@19 lld@19 gcc-arm-embedded cmake ninja qemu clang-format yapf 
brew tap riscv-software-src/riscv
brew install riscv-tools riscv64-elf-gcc riscv64-elf-binutils riscv64-elf-gdb
python3 -m pip install --user --break-system-packages --upgrade kconfiglib

# download repo
if [[ ! -f "$OPT_PATH/bin/repo" ]]; then
    curl -L "https://mirrors.tuna.tsinghua.edu.cn/git/git-repo" -o "$OPT_PATH/bin/repo"
    chmod +x $OPT_PATH/bin/repo
fi
# download gn
if [[ ! -f "$OPT_PATH/bin/gn" ]]; then
    wget -c --tries=3 --timeout=10 "https://chrome-infra-packages.appspot.com/dl/gn/gn/mac-amd64/+/latest" -O gn.zip
    unzip gn.zip -d $OPT_PATH/bin
    rm gn.zip
    chmod +x $OPT_PATH/bin/gn
fi

# download arm/aarch64 toolchains
ARM_TOOLCHAIN_DIR="$OPT_PATH/arm-gnu-toolchain-14.3.rel1-darwin-arm64-arm-none-eabi"
AARCH64_TOOLCHAIN_DIR="$OPT_PATH/arm-gnu-toolchain-14.3.rel1-darwin-arm64-aarch64-none-elf"

# Check if toolchains already exist
if [[ -d "$ARM_TOOLCHAIN_DIR" && -d "$AARCH64_TOOLCHAIN_DIR" ]]; then
    echo "ARM toolchains already exist, skipping download and extraction"
else
    echo "Downloading ARM toolchains..."
    wget -c --tries=3 --timeout=10 "https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/arm-gnu-toolchain-14.3.rel1-darwin-arm64-arm-none-eabi.tar.xz"
    wget -c --tries=3 --timeout=10 "https://developer.arm.com/-/media/Files/downloads/gnu/14.3.rel1/binrel/arm-gnu-toolchain-14.3.rel1-darwin-arm64-aarch64-none-elf.tar.xz"
    tar xf arm-gnu-toolchain-14.3.rel1-darwin-arm64-arm-none-eabi.tar.xz -C $OPT_PATH
    tar xf arm-gnu-toolchain-14.3.rel1-darwin-arm64-aarch64-none-elf.tar.xz -C $OPT_PATH
    rm arm-gnu-toolchain-14.3.rel1-darwin-arm64-arm-none-eabi.tar.xz
    rm arm-gnu-toolchain-14.3.rel1-darwin-arm64-aarch64-none-elf.tar.xz
fi

# Create symlinks if they don't exist
if [[ ! -L "$OPT_PATH/aarch64-none-elf" ]]; then
    ln -sfn $OPT_PATH/arm-gnu-toolchain-14.3.rel1-darwin-arm64-aarch64-none-elf $OPT_PATH/aarch64-none-elf
fi

if [[ ! -L "$OPT_PATH/arm-none-eabi" ]]; then
    ln -sfn $OPT_PATH/arm-gnu-toolchain-14.3.rel1-darwin-arm64-arm-none-eabi $OPT_PATH/arm-none-eabi
fi

# build toolchain
export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
export CARGO_NET_GIT_FETCH_WITH_CLI=true
export DESTDIR=$SYSROOT_PATH

mkdir -p $SYSROOT_PATH/src
cd $SYSROOT_PATH/src
git clone git@github.com:vivoblueos/rust.git
git clone git@github.com:vivoblueos/cc-rs.git
git clone git@github.com:vivoblueos/libc.git
cd rust
cp config.blueos.toml config.toml
./x.py install -i --stage 1 compiler/rustc
./x.py install -i --stage 1 library/std --target aarch64-vivo-blueos-newlib
./x.py install -i --stage 1 library/std --target thumbv7m-vivo-blueos-newlibeabi
./x.py install -i --stage 1 library/std --target thumbv8m.main-vivo-blueos-newlibeabihf
./x.py install -i --stage 1 library/std --target riscv64-vivo-blueos
./x.py install -i --stage 1 library/std --target riscv32-vivo-blueos
./x.py install -i --stage 1 library/std --target riscv32imc-vivo-blueos
./x.py install -i --stage 0 rustfmt
./x.py install -i --stage 0 rust-analyzer
./x.py install -i --stage 0 clippy
./x.py install -i --stage 1 library/std --target aarch64-apple-darwin
cp -av build/aarch64-apple-darwin/llvm/{bin,lib} ${DESTDIR}/usr/local

# export PATH
export PATH=${DESTDIR}/usr/local/bin:$OPT_PATH/bin:$OPT_PATH/aarch64-none-elf/bin:$OPT_PATH/arm-none-eabi/bin:$PATH

cd $SRC_PATH
repo init -u git@github.com:vivoblueos/manifests.git -b main -m manifest.xml
repo sync -j$(nproc)

LLVM19_VERSION=$(brew list --versions llvm@19 | awk '{print $2}')
LLVM19_PATH=$(brew --prefix llvm@19)"/$LLVM19_VERSION"
LLD19_PATH=$(brew --prefix lld@19)

echo "
 add toolchain PATH to your .bashrc

export SDKROOT=`/usr/bin/xcrun --show-sdk-path -sdk macosx`
export LDFLAGS="-L$SDKROOT/usr/lib"
export CPPFLAGS="-I$LLVM19_PATH/include"
export PATH=${DESTDIR}/usr/local/bin:$OPT_PATH/bin:$OPT_PATH/aarch64-none-elf/bin:$OPT_PATH/arm-none-eabi/bin:$LLD19_PATH/bin:\$PATH
"