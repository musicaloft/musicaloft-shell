//! Greeting logic for the crane-simple test project.

use heck::ToTitleCase;

/// The greeting template. It lives in a text file so the build depends on
/// a non-Rust source file kept through `extraFileTypes`.
const TEMPLATE: &str = include_str!("greeting.txt");

/// Builds a greeting for `name`, title-casing it first.
///
/// With the `shout` feature enabled, the whole greeting is uppercased.
///
/// # Example
/// ```
/// let greeting = crane_simple::greeting("crane simple");
/// assert!(greeting.to_lowercase().contains("crane simple"));
/// ```
pub fn greeting(name: &str) -> String {
    let greeting = TEMPLATE.trim_end().replace("{name}", &name.to_title_case());

    if cfg!(feature = "shout") {
        greeting.to_uppercase()
    } else {
        greeting
    }
}

#[cfg(test)]
mod tests {
    use super::greeting;

    #[test]
    #[cfg(not(feature = "shout"))]
    fn greets_by_title_cased_name() {
        assert_eq!(greeting("crane simple"), "hello from Crane Simple!");
    }

    #[test]
    #[cfg(feature = "shout")]
    fn shouts_the_greeting() {
        assert_eq!(greeting("crane simple"), "HELLO FROM CRANE SIMPLE!");
    }
}
