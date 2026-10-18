//! Shared logic for the crane-workspace test project's binaries.

use heck::ToTitleCase;

/// Builds the banner a workspace binary prints, title-casing its name.
///
/// # Example
/// ```
/// assert_eq!(workspace_core::banner("my tool"), "[My Tool] ready");
/// ```
pub fn banner(name: &str) -> String {
    format!("[{}] ready", name.to_title_case())
}

/// Counts the whitespace-separated words in `text`.
///
/// # Example
/// ```
/// assert_eq!(workspace_core::word_count("one two  three"), 3);
/// ```
pub fn word_count(text: &str) -> usize {
    text.split_whitespace().count()
}

#[cfg(test)]
mod tests {
    use super::{banner, word_count};

    #[test]
    fn banner_title_cases_the_name() {
        assert_eq!(banner("workspace cli"), "[Workspace Cli] ready");
    }

    #[test]
    fn word_count_ignores_repeated_whitespace() {
        assert_eq!(word_count("  a  b\tc\n"), 3);
    }
}
