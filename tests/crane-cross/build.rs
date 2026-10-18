//! Exposes the target triple to the crate. Cross builds run this script on
//! the build platform, so it also tests that build scripts are compiled for
//! the right platform.

fn main() {
    let target = std::env::var("TARGET").expect("cargo always sets TARGET for build scripts");
    println!("cargo::rustc-env=CRANE_CROSS_TARGET={target}");

    // libz-sys quietly falls back to building its own zlib when pkg-config
    // doesn't work, which would hide a pkg-config built for the wrong
    // platform
    #[cfg(feature = "zlib")]
    if let Err(error) = pkg_config::probe_library("zlib") {
        panic!(
            "pkg-config couldn't find zlib for {target}. is pkg-config in nativeBuildInputs and \
             zlib in buildInputs? {error}"
        );
    }
}
