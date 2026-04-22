#!/bin/sh
set -eu

repo_root=$(
    CDPATH= cd -- "$(dirname "$0")/../../.." && pwd
)

host_triple=${HOST_TRIPLE:?HOST_TRIPLE is required}
rust_build_dir=${RUST_BUILD_DIR:-"$repo_root/build"}
llvm_toolchain_dir=${LLVM_TOOLCHAIN_DIR:-"$repo_root/llvm-toolchain"}
toolchain_output_dir=${TOOLCHAIN_OUTPUT_DIR:-"$repo_root"}
rust_source_dir=${RUST_SOURCE_DIR:-"$repo_root"}
snapshot_rustc=${SNAPSHOT_RUSTC:-}

if [ -z "$snapshot_rustc" ]; then
    snapshot_rustc=$(rustup which rustc)
fi
snapshot_sysroot=${SNAPSHOT_SYSROOT:-"$("$snapshot_rustc" --print sysroot)"}
bootstrap_rustc=${BOOTSTRAP_RUSTC:-"$rust_build_dir/bootstrap/debug/rustc"}

stage2_dir="$rust_build_dir/$host_triple/stage2"
stage2_tools_dir="$rust_build_dir/$host_triple/stage2-tools-bin"
stage1_dir="$rust_build_dir/$host_triple/stage1"
stage0_dir="$rust_build_dir/$host_triple/stage0"

host_stage2_lib_dir="$stage2_dir/lib/rustlib/$host_triple/lib"
host_stage1_lib_dir="$stage1_dir/lib/rustlib/$host_triple/lib"
host_stage2_bin_dir="$stage2_dir/lib/rustlib/$host_triple/bin"
host_stage0_bin_dir="$stage0_dir/lib/rustlib/$host_triple/bin"
target_stage2_lib_dir="$stage2_dir/lib/rustlib/tc32-unknown-none-elf/lib"
target_lib_source_dir=${TARGET_LIB_SOURCE_DIR:-"$target_stage2_lib_dir"}

host_lib_source_dir="$host_stage2_lib_dir"
if [ ! -d "$host_lib_source_dir" ] || [ -z "$(find "$host_lib_source_dir" -maxdepth 1 -type f | head -n 1)" ]; then
    host_lib_source_dir="$host_stage1_lib_dir"
fi

rust_objcopy_source=
for candidate in \
    "${RUST_OBJCOPY_SOURCE:-}" \
    "$host_stage2_bin_dir/rust-objcopy" \
    "$host_stage0_bin_dir/rust-objcopy"; do
    if [ -n "${candidate:-}" ] && [ -x "$candidate" ]; then
        rust_objcopy_source="$candidate"
        break
    fi
done

for required in \
    "$stage2_dir/bin/rustc" \
    "$stage2_tools_dir/cargo" \
    "$bootstrap_rustc" \
    "$snapshot_rustc" \
    "$snapshot_sysroot/lib" \
    "$host_lib_source_dir" \
    "$target_lib_source_dir" \
    "$llvm_toolchain_dir/bin/clang" \
    "$llvm_toolchain_dir/bin/ld.lld" \
    "$llvm_toolchain_dir/bin/llvm-objcopy" \
    "$rust_source_dir/.git" \
    "$rust_objcopy_source"; do
    if [ ! -e "$required" ]; then
        echo "missing required input: $required" >&2
        exit 1
    fi
done

out_dir="$toolchain_output_dir/tc32-stage2-$host_triple"
current_link="$toolchain_output_dir/tc32-stage2"
tmp_dir="$out_dir.tmp"

copy_checkout_tree() {
    src_repo=$1
    dst_dir=$2
    rm -rf "$dst_dir"
    mkdir -p "$dst_dir"
    git -C "$src_repo" archive --format=tar HEAD | tar -C "$dst_dir" -xf -
}

rm -rf "$tmp_dir"
mkdir -p \
    "$tmp_dir/bin" \
    "$tmp_dir/lib" \
    "$tmp_dir/llvm/bin" \
    "$tmp_dir/llvm/lib" \
    "$tmp_dir/snapshot/bin" \
    "$tmp_dir/snapshot/lib"

cp "$stage2_dir/bin/rustc" "$tmp_dir/bin/rustc-real"
cp "$stage2_tools_dir/cargo" "$tmp_dir/bin/cargo-real"
cp "$bootstrap_rustc" "$tmp_dir/bin/rustc-bootstrap"
cp "$snapshot_rustc" "$tmp_dir/snapshot/bin/rustc"
cp -R "$stage2_dir/lib/." "$tmp_dir/lib/"
cp -R "$snapshot_sysroot/lib/." "$tmp_dir/snapshot/lib/"
cp -R "$llvm_toolchain_dir/bin/." "$tmp_dir/llvm/bin/"
if [ -d "$llvm_toolchain_dir/lib/clang" ]; then
    cp -R "$llvm_toolchain_dir/lib/clang" "$tmp_dir/llvm/lib/"
fi

mkdir -p \
    "$tmp_dir/lib/rustlib/$host_triple/bin" \
    "$tmp_dir/lib/rustlib/$host_triple/lib" \
    "$tmp_dir/lib/rustlib/tc32-unknown-none-elf/lib"
rm -rf \
    "$tmp_dir/lib/rustlib/$host_triple/lib" \
    "$tmp_dir/lib/rustlib/tc32-unknown-none-elf/lib" \
    "$tmp_dir/lib/rustlib/src" \
    "$tmp_dir/lib/rustlib/rustc-src"
mkdir -p \
    "$tmp_dir/lib/rustlib/$host_triple/lib" \
    "$tmp_dir/lib/rustlib/tc32-unknown-none-elf/lib"
cp -R "$host_lib_source_dir/." "$tmp_dir/lib/rustlib/$host_triple/lib/"
cp -R "$target_lib_source_dir/." "$tmp_dir/lib/rustlib/tc32-unknown-none-elf/lib/"
cp "$rust_objcopy_source" "$tmp_dir/lib/rustlib/$host_triple/bin/rust-objcopy"

copy_checkout_tree "$rust_source_dir" "$tmp_dir/lib/rustlib/src/rust"
copy_checkout_tree "$rust_source_dir" "$tmp_dir/lib/rustlib/rustc-src/rust"

cat >"$tmp_dir/toolchain.toml" <<EOF
host_triple = "$host_triple"
target_triple = "tc32-unknown-none-elf"
channel = "stage2-local"

[paths]
cargo = "bin/cargo"
rustc = "bin/rustc"
real_rustc = "bin/rustc-real"
bootstrap_rustc = "bin/rustc-bootstrap"
snapshot_rustc = "snapshot/bin/rustc"
sysroot = "."
llvm_bin = "llvm/bin"
EOF

cat >"$tmp_dir/bin/rustc" <<'EOF'
#!/bin/sh
set -eu

root=$(
    CDPATH= cd -- "$(dirname "$0")/.." && pwd
)

host_dylib_var() {
    case "$(uname -s)" in
        Darwin) printf '%s\n' DYLD_FALLBACK_LIBRARY_PATH ;;
        Linux) printf '%s\n' LD_LIBRARY_PATH ;;
        *) printf '%s\n' LD_LIBRARY_PATH ;;
    esac
}

has_sysroot=0
prev=
for arg in "$@"; do
    if [ "$prev" = "--sysroot" ]; then
        has_sysroot=1
        break
    fi
    case "$arg" in
        --sysroot|--sysroot=*)
            has_sysroot=1
            break
            ;;
    esac
    prev=$arg
done

compiler="$root/bin/rustc-real"
libdir="$root/lib"
if [ "$has_sysroot" -eq 0 ]; then
    set -- "$@" --sysroot "$root"
fi

dylib_var=$(host_dylib_var)
eval "old_dylib_path=\${$dylib_var-}"
if [ -n "${old_dylib_path:-}" ]; then
    new_dylib_path="$libdir:$old_dylib_path"
else
    new_dylib_path="$libdir"
fi

env "$dylib_var=$new_dylib_path" "$compiler" "$@"
EOF

cat >"$tmp_dir/bin/cargo" <<'EOF'
#!/bin/sh
set -eu

root=$(
    CDPATH= cd -- "$(dirname "$0")/.." && pwd
)

export RUSTC="${RUSTC:-$root/bin/rustc}"
export TC32_LLVM_BIN="${TC32_LLVM_BIN:-$root/llvm/bin}"
export CARGO_TARGET_TC32_UNKNOWN_NONE_ELF_LINKER="${CARGO_TARGET_TC32_UNKNOWN_NONE_ELF_LINKER:-$root/llvm/bin/ld.lld}"

exec "$root/bin/cargo-real" "$@"
EOF

chmod +x "$tmp_dir/bin/rustc" "$tmp_dir/bin/cargo"

driver_root=$(find "$tmp_dir/lib" -maxdepth 1 -type f -name 'librustc_driver-*' | head -n 1 || true)
driver_host=$(find "$tmp_dir/lib/rustlib/$host_triple/lib" -maxdepth 1 -type f -name 'librustc_driver-*' | head -n 1 || true)
if [ -n "$driver_root" ] && [ -n "$driver_host" ] && ! cmp -s "$driver_root" "$driver_host"; then
    echo "packaged toolchain has mismatched librustc_driver copies:" >&2
    echo "  $driver_root" >&2
    echo "  $driver_host" >&2
    exit 1
fi

if [ -L "$tmp_dir/lib/rustlib/src/rust" ] || [ -L "$tmp_dir/lib/rustlib/rustc-src/rust" ]; then
    echo "packaged toolchain still contains top-level rust source symlinks" >&2
    exit 1
fi

rm -rf "$out_dir"
mkdir -p "$toolchain_output_dir"
mv "$tmp_dir" "$out_dir"
ln -sfn "$(basename "$out_dir")" "$current_link"

printf 'packaged toolchain: %s\n' "$out_dir"
printf 'stable link: %s\n' "$current_link"
