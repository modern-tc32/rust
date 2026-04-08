//@ add-minicore
//@ revisions: base thumb
//@[base] compile-flags: --target tc32-unknown-none-elf
//@[thumb] compile-flags: --target tc32-unknown-none-elf -C target-feature=+thumb-mode
//@ needs-llvm-components: arm
//@ build-pass
//@ ignore-backends: gcc

#![feature(no_core)]
#![crate_type = "rlib"]
#![no_core]

extern crate minicore;
use minicore::*;

global_asm!("tmov r0, r0");

#[no_mangle]
pub unsafe fn inline_tc32() -> u32 {
    let value: u32;
    asm!("tmov r0, r0", lateout("r0") value, options(nomem, nostack));
    value
}

#[no_mangle]
#[unsafe(naked)]
pub extern "C" fn naked_tc32() {
    naked_asm!("tmov r0, r0", "tjex lr");
}

#[cfg(thumb)]
#[no_mangle]
#[unsafe(naked)]
#[instruction_set(arm::t32)]
pub extern "C" fn naked_tc32_thumb() {
    naked_asm!("tmov r0, r0", "tjex lr");
}
