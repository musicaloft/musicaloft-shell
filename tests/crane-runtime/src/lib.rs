//! Runtime dependency checks for the crane-runtime test project.
//!
//! The crate asks zlib for its version in a way that only works if the
//! built binary can find `libz.so.1` when it runs.

mod loaded;

/// Asks zlib for its version, loading `libz.so.1` while the program runs.
///
/// The library isn't linked at build time, so nothing but the binary's
/// rpath can make it findable. An error means the binary couldn't load it.
pub fn zlib_version() -> Result<String, String> {
    loaded::zlib_version()
}

/// Describes where zlib's version came from.
///
/// # Example
/// ```
/// assert_eq!(crane_runtime::describe("1.3.1"), "loaded zlib 1.3.1");
/// ```
pub fn describe(version: &str) -> String {
    format!("loaded zlib {version}")
}

#[cfg(test)]
mod tests {
    use super::describe;

    // the nextest binaries aren't patched with runtime dependencies, so
    // these tests can't load zlib themselves
    #[test]
    fn describes_the_version() {
        assert_eq!(describe("1.3.1"), "loaded zlib 1.3.1");
    }
}
