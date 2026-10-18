//! Platform reporting for the crane-cross test project.

/// The target triple this crate was compiled for.
pub const TARGET: &str = env!("CRANE_CROSS_TARGET");

/// Adds two numbers.
///
/// Exported unmangled, so it's callable from the host when this crate is
/// built as a bare wasm module.
///
/// # Example
/// ```
/// assert_eq!(crane_cross::add(2, 3), 5);
/// ```
#[unsafe(no_mangle)]
pub extern "C" fn add(left: i32, right: i32) -> i32 {
    left + right
}

/// Returns the version of the zlib this crate is linked against.
#[cfg(feature = "zlib")]
pub fn zlib_version() -> String {
    // SAFETY: zlibVersion returns a pointer to a static, nul-terminated
    // string
    let version = unsafe { std::ffi::CStr::from_ptr(libz_sys::zlibVersion()) };
    version.to_string_lossy().into_owned()
}

/// Describes this build: its target and, with the `zlib` feature, the
/// linked zlib version.
///
/// # Example
/// ```
/// assert!(crane_cross::describe().starts_with("hello from "));
/// ```
pub fn describe() -> String {
    #[cfg(feature = "zlib")]
    let linked = format!(" with zlib {}", zlib_version());
    #[cfg(not(feature = "zlib"))]
    let linked = String::new();

    format!("hello from {TARGET}{linked}, 2 + 3 = {}", add(2, 3))
}

#[cfg(test)]
mod tests {
    use super::{add, describe};

    #[test]
    fn adds() {
        assert_eq!(add(-2, 3), 1);
    }

    #[test]
    fn describes_the_target() {
        assert!(describe().contains(super::TARGET));
    }
}
