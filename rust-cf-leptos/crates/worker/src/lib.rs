#![allow(non_snake_case)]

use app::{shell, App};
use axum::{Extension, Router};
use http_body_util::BodyExt;
use leptos_axum::{generate_route_list, LeptosRoutes};
use leptos_config::LeptosOptions;
use std::sync::Arc;
use tower_service::Service;
use worker::{
    event, Context, Env, HttpRequest, HttpResponse as WorkerHttpResponse, Request as WorkerRequest,
    Result,
};

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
        .without_v07_checks()
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

    let method = req.method().clone();
    let path = req.uri().path().to_string();
    let worker_req = WorkerRequest::try_from(req)?;
    log::info!("fetch called for {} {}", method, path);

    if let Some(asset_response) = serve_static_asset(&worker_req, &env).await? {
        return Ok(asset_response);
    }

    let req = worker::HttpRequest::try_from(worker_req)?;

    Ok(router(env).call(req).await?)
}

async fn serve_static_asset(
    req: &WorkerRequest,
    env: &Env,
) -> Result<Option<axum::http::Response<axum::body::Body>>> {
    let path = req.path();
    if path != "/pkg" && !path.starts_with("/pkg/") {
        return Ok(None);
    }

    let fetcher = match env.assets("ASSETS") {
        Ok(fetcher) => fetcher,
        Err(err) => {
            log::error!("static asset binding missing: {err}");
            return Ok(None);
        }
    };

    let js_request = match web_sys::Request::try_from(req) {
        Ok(req) => req,
        Err(err) => {
            log::error!("failed to clone request for asset fetch: {err}");
            return Ok(None);
        }
    };

    match fetcher.fetch_request(js_request).await {
        Ok(response) => convert_asset_response(response).await.map(Some),
        Err(err) => {
            log::error!("asset fetch failed for {path}: {err}");
            Ok(None)
        }
    }
}

async fn convert_asset_response(
    response: WorkerHttpResponse,
) -> Result<axum::http::Response<axum::body::Body>> {
    let (parts, body) = response.into_parts();
    let bytes = body.collect().await?.to_bytes();
    Ok(axum::http::Response::from_parts(
        parts,
        axum::body::Body::from(bytes),
    ))
}
