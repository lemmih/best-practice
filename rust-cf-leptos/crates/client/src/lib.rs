#![allow(non_snake_case)]

use app::App;
use leptos::mount;
use wasm_bindgen::prelude::wasm_bindgen;

#[wasm_bindgen]
pub fn hydrate() {
    _ = console_log::init_with_level(log::Level::Debug);
    console_error_panic_hook::set_once();
    mount::hydrate_body(App);
}
