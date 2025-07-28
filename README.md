# toolchain
We provide prebuilt binary
[tarballs](https://github.com/vivoblueos/toolchain/releases) for BlueOS
development.

# Build on macOS
We have offered a script `build_for_mac.sh` to download and build the toolchain at one-click. Usage:
```bash
mkdir -p <your_dev_path>/blueos_dev
cd <your_dev_path>/blueos_dev
./build_for_mac.sh --sysroot ../blueos_sysroot
# add export to your .bashrc
./build/ci/run_ci.py
```