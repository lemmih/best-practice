#![allow(non_snake_case)]

use app::{App, shell};
use axum::{Extension, Router};
use leptos_axum::{LeptosRoutes, generate_route_list};
use leptos_config::LeptosOptions;
use std::sync::Arc;
use tower_service::Service;
use worker::{Context, Env, HttpRequest, Result, event};

fn router(env: Env) -> Router<()> {
    let leptos_options = LeptosOptions::builder()
        .output_name("client")
        .site_pkg_dir("pkg")
        .build();
    let routes = generate_route_list(App);
    for route in routes.iter() {
        log::info!("Registering Leptos route {}", route.path());
    }

    Router::new()
        .leptos_routes(&leptos_options, routes, {
            let leptos_options = leptos_options.clone();
            move || shell(leptos_options.clone())
        })
        .with_state(leptos_options)
        .layer(Extension(Arc::new(env)))
}

#[event(fetch)]
pub async fn fetch(
    req: HttpRequest,
    env: Env,
    _ctx: Context,
) -> Result<axum::http::Response<axum::body::Body>> {
    _ = console_log::init_with_level(log::Level::Debug);
    console_error_panic_hook::set_once();

    log::info!("fetch called for {} {}", req.method(), req.uri().path());

    Ok(router(env).call(req).await?)
}
