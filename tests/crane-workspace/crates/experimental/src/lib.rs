//! Excluded from the workspace, so building it means member resolution
//! ignored `workspace.exclude`.

compile_error!("crates/experimental is excluded from the workspace and must never be built");
