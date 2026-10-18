//! Server functions shared by every frontend in the workspace.

use dioxus::prelude::*;

/// Greets the client from the server.
#[get("/api/greeting")]
pub async fn greeting() -> Result<String> {
    Ok("the api crate says hello".to_string())
}
