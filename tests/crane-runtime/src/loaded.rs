//! Loads zlib while the program runs.

use std::ffi::{CStr, c_char};

use libloading::{Library, Symbol};

/// The soname zlib is loaded by.
const LIBRARY: &str = "libz.so.1";

/// Loads zlib and calls its `zlibVersion` function.
pub fn zlib_version() -> Result<String, String> {
    // SAFETY: loading zlib runs no initialization code that could break
    // our assumptions, and `zlibVersion` has this exact signature.
    unsafe {
        let library = Library::new(LIBRARY).map_err(|error| {
            format!("couldn't load {LIBRARY}. is zlib in runtimeDependencies? {error}")
        })?;
        let zlib_version: Symbol<unsafe extern "C" fn() -> *const c_char> = library
            .get(b"zlibVersion\0")
            .map_err(|error| format!("couldn't find zlibVersion in {LIBRARY}: {error}"))?;

        Ok(CStr::from_ptr(zlib_version())
            .to_string_lossy()
            .into_owned())
    }
}
