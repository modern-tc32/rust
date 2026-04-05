# `tc32-unknown-none-elf`

* **Tier: 3**
* **Library Support:** core and alloc (bare-metal, `#![no_std]`)

Bare-metal target for Telink TC32 microcontrollers using a TC32-enabled LLVM.

This target is exposed to Rust as `target_arch = "tc32"`, but it reuses the
ARM-derived ABI lowering and inline assembly surface implemented in the local
LLVM backend. It is intended for firmware-style builds without an OS, without
unwinding, and without `std`.

## Building the target

This target requires a local Rust build that uses the in-tree LLVM with TC32
support. Do not use CI-downloaded LLVM for this target; set
`llvm.download-ci-llvm = false` in `bootstrap.toml`.

To build `core`, `alloc`, and `compiler_builtins` for the target:

```sh
cargo +stage1 build -Zbuild-std=core,alloc,compiler_builtins --target tc32-unknown-none-elf
```

You will typically also need a linker script and startup code for your board or
SDK.

## Target maintainers

This target is maintained out of tree in this repository.
