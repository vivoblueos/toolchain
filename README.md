# toolchain
We provide prebuilt binary
[tarballs](https://github.com/vivoblueos/toolchain/releases) for BlueOS
development.

# build_mac.sh
We provide the build_mac.sh script for one-click download and build of the toolchain. Usage:
```bash
mkdir -p <your_dev_path>/blueos_dev
cd <your_dev_path>/blueos_dev
./build_mac.sh --sysroot ../blueos_sysroot
# add export to your .bashrc
./build/ci/run_ci.py
```