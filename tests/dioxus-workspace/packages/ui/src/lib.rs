//! Components shared by every frontend in the workspace.

use dioxus::prelude::*;

// lives in this crate's own assets directory, not the app's
const BANNER_CSS: Asset = asset!("/assets/banner.css");

/// A banner showing the api crate's greeting, fetched while rendering on
/// the server.
#[component]
pub fn Banner() -> Element {
    let greeting = use_server_future(api::greeting)?;

    let greeting = match &*greeting.read() {
        Some(Ok(greeting)) => greeting.clone(),
        Some(Err(error)) => format!("the server couldn't greet us: {error}"),
        None => "waiting for the server...".to_string(),
    };

    rsx! {
        document::Stylesheet { href: BANNER_CSS }

        section { id: "banner",
            h1 { class: "text-3xl font-bold", "hello from the ui crate" }
            p { "{greeting}" }
        }
    }
}
