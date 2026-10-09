//@ add-minicore
//@ compile-flags: --target tc32-unknown-none-elf
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

// `tadd`/`tmov` with high registers are rewritten to `add`/`mov`; labels, comments and `;`
// separators must not confuse that rewrite.
#[no_mangle]
pub unsafe fn inline_tc32_high_regs(x: u32) {
    asm!(
        "1: tmov r8, r1 // tmov r9, r1",
        "tadd r8, r1; tmov r8, r1 @ tadd r9, r1",
        in("r1") x,
        out("r8") _,
        options(nomem, nostack),
    );
}

#[no_mangle]
#[unsafe(naked)]
pub extern "C" fn naked_tc32() {
    naked_asm!("tmov r0, r0", "tjex lr");
}
