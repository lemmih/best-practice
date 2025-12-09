use leptos::{
    hydration::{AutoReload, HydrationScripts},
    prelude::*,
};
use leptos_config::LeptosOptions;
use leptos_meta::{MetaTags, provide_meta_context};
use leptos_router::{
    components::{Route, Router, Routes},
    path,
};

/// A simple server function that adds two numbers on the server.
/// This demonstrates server-side computation with Leptos server functions.
#[server(AddNumbers, "/api")]
pub async fn add_numbers(a: i32, b: i32) -> Result<i32, ServerFnError> {
    // This code only runs on the server
    Ok(a + b)
}

#[component]
fn Home() -> impl IntoView {
    let (count, set_count) = signal(0);
    let increment = move |_| *set_count.write() += 1;

    // Server function action
    let add_action = ServerAction::<AddNumbers>::new();
    let result = add_action.value();

    view! {
      <section class="mx-auto max-w-2xl space-y-6 py-12 text-center">
        <h1 class="text-4xl font-bold tracking-tight text-slate-900">"Leptos on Cloudflare"</h1>
        <p class="text-slate-600">"Minimal Leptos skeleton rendered server-side on Cloudflare Workers."</p>
        <div class="flex items-center justify-center gap-4">
          <a class="rounded bg-slate-900 px-4 py-2 font-semibold text-white hover:bg-slate-700" href="/">
            "Refresh"
          </a>
          <button
            class="rounded border border-slate-300 bg-white px-4 py-2 font-semibold text-slate-800 shadow-sm hover:bg-slate-50"
            on:click=increment
          >
            "Clicks: "
            <span class="font-mono">{count}</span>
          </button>
        </div>

        // Server function demo section
        <div class="mt-8 rounded-lg border border-slate-200 bg-white p-6 shadow-sm">
          <h2 class="mb-4 text-xl font-semibold text-slate-800">"Server Function Demo"</h2>
          <p class="mb-4 text-slate-600">"Click the button to compute 2 + 3 on the server."</p>
          <ActionForm action=add_action>
            <input type="hidden" name="a" value="2" />
            <input type="hidden" name="b" value="3" />
            <button type="submit" class="rounded bg-blue-600 px-4 py-2 font-semibold text-white hover:bg-blue-500">
              "Calculate 2 + 3"
            </button>
          </ActionForm>
          <p class="mt-4 text-lg" id="server-result">
            "Result: "
            <span class="font-mono font-bold">
              {move || match result.get() {
                Some(Ok(val)) => val.to_string(),
                Some(Err(e)) => format!("Error: {}", e),
                None => "—".to_string(),
              }}
            </span>
          </p>
        </div>
      </section>
    }
}

#[component]
pub fn App() -> impl IntoView {
    provide_meta_context();

    view! {
      <Router>
        <main class="min-h-screen bg-slate-100 px-4">
          <Routes fallback=|| "Not found">
            <Route path=path!("/") view=Home />
          </Routes>
        </main>
      </Router>
    }
}

pub fn shell(options: LeptosOptions) -> impl IntoView {
    view! {
      <!DOCTYPE html>
      <html lang="en">
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <link rel="stylesheet" href="/pkg/styles.css" />
          <AutoReload options=options.clone() />
          <HydrationScripts options />
          <MetaTags />
          <title>"Leptos on Cloudflare"</title>
        </head>
        <body class="bg-slate-100 text-slate-900">
          <App />
        </body>
      </html>
    }
}
