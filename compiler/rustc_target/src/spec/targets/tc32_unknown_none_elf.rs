use crate::spec::{
    Arch, Cc, Env, FloatAbi, LinkerFlavor, Lld, Os, PanicStrategy, RelocModel, Target,
    TargetMetadata, TargetOptions,
};

pub(crate) fn target() -> Target {
    Target {
        llvm_target: "tc32-unknown-none-elf".into(),
        metadata: TargetMetadata {
            description: Some("Bare-metal Telink TC32".into()),
            tier: Some(3),
            host_tools: Some(false),
            std: Some(false),
        },
        pointer_width: 32,
        data_layout: "e-m:e-p:32:32-Fi8-i64:64-v128:64:128-a:0:32-n32-S64".into(),
        arch: Arch::Tc32,
        options: TargetOptions {
            os: Os::None,
            env: Env::Unspecified,
            vendor: "unknown".into(),
            linker_flavor: LinkerFlavor::Gnu(Cc::No, Lld::Yes),
            linker: Some("rust-lld".into()),
            llvm_floatabi: Some(FloatAbi::Soft),
            panic_strategy: PanicStrategy::Abort,
            relocation_model: RelocModel::Static,
            emit_debug_gdb_scripts: false,
            eh_frame_header: false,
            features: "+strict-align".into(),
            atomic_cas: false,
            max_atomic_width: Some(32),
            c_enum_min_bits: Some(8),
            ..Default::default()
        },
    }
}
