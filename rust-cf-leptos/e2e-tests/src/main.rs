use anyhow::{Context, Result};
use std::time::Duration;
use thirtyfour::prelude::*;

struct TestRunner {
    driver: WebDriver,
    base_url: String,
}

impl TestRunner {
    async fn new() -> Result<Self> {
        let base_url =
            std::env::var("E2E_BASE_URL").unwrap_or_else(|_| "http://127.0.0.1:8787".to_string());

        let webdriver_port = std::env::var("WEBDRIVER_PORT").unwrap_or_else(|_| "4444".to_string());

        let mut caps = DesiredCapabilities::firefox();
        caps.set_headless()?;

        let driver = WebDriver::new(&format!("http://localhost:{}", webdriver_port), caps)
            .await
            .context("creating WebDriver connection")?;

        driver
            .set_implicit_wait_timeout(Duration::from_secs(10))
            .await?;

        Ok(Self { driver, base_url })
    }

    async fn get_page_source(&self) -> Result<String> {
        self.driver.goto(&self.base_url).await?;
        self.driver.source().await.context("getting page source")
    }

    async fn get_css_content(&self) -> Result<String> {
        let css_url = format!("{}/pkg/styles.css", self.base_url);
        self.driver.goto(&css_url).await?;
        self.driver.source().await.context("getting CSS content")
    }
}

impl TestRunner {
    async fn quit(self) -> Result<()> {
        self.driver.quit().await.context("quitting WebDriver")
    }
}

// ============================================================================
// Test Definitions
// ============================================================================

/// Test: Main page is reachable and contains expected content
async fn test_main_page_reachable(runner: &TestRunner) -> Result<()> {
    let body = runner.get_page_source().await?;

    assert!(
        body.contains("Leptos on Cloudflare"),
        "HTML should contain 'Leptos on Cloudflare'"
    );

    Ok(())
}

/// Test: CSS stylesheet link is present in HTML head
async fn test_css_link_present(runner: &TestRunner) -> Result<()> {
    let body = runner.get_page_source().await?;

    assert!(
        body.contains(r#"href="/pkg/styles.css""#) && body.contains("stylesheet"),
        "HTML should contain CSS link tag with /pkg/styles.css"
    );

    Ok(())
}

/// Test: CSS file is accessible and not empty
async fn test_css_file_accessible(runner: &TestRunner) -> Result<()> {
    let css_content = runner.get_css_content().await?;

    assert!(!css_content.is_empty(), "CSS file should not be empty");
    assert!(
        css_content.len() >= 100,
        "CSS file should have sufficient content (at least 100 bytes, got {})",
        css_content.len()
    );

    Ok(())
}

/// Test: CSS contains required Tailwind utility classes
async fn test_css_contains_tailwind_classes(runner: &TestRunner) -> Result<()> {
    let css_content = runner.get_css_content().await?;

    // Classes that should be present based on the HTML structure
    let required_classes = [
        (".mx-auto", "section element"),
        (".flex", "div container"),
        (".items-center", "flex container"),
        (".justify-center", "flex container"),
        (".text-center", "section element"),
        (".min-h-screen", "main element"),
    ];

    let mut missing = Vec::new();
    for (class, context) in &required_classes {
        if !css_content.contains(class) {
            missing.push(format!("{} (used in {})", class, context));
        }
    }

    assert!(
        missing.is_empty(),
        "CSS should contain all required Tailwind classes. Missing: {:?}",
        missing
    );

    Ok(())
}

/// Test: CSS is valid Tailwind CSS output
async fn test_css_is_valid_tailwind(runner: &TestRunner) -> Result<()> {
    let css_content = runner.get_css_content().await?;

    assert!(
        css_content.contains("tailwindcss"),
        "CSS should contain Tailwind CSS identifier"
    );

    Ok(())
}

/// Test: Server function demo section is present
async fn test_server_function_section_present(runner: &TestRunner) -> Result<()> {
    let body = runner.get_page_source().await?;

    assert!(
        body.contains("Server Function Demo"),
        "HTML should contain 'Server Function Demo' section"
    );
    assert!(
        body.contains("Calculate 2 + 3"),
        "HTML should contain the server function button"
    );

    Ok(())
}

/// Test: Server function executes and returns correct result
async fn test_server_function_executes(runner: &TestRunner) -> Result<()> {
    runner.driver.goto(&runner.base_url).await?;

    // Find and click the "Calculate 2 + 3" button
    let button = runner
        .driver
        .find(By::XPath("//button[contains(text(), 'Calculate 2 + 3')]"))
        .await
        .context("finding server function button")?;

    button
        .click()
        .await
        .context("clicking server function button")?;

    // Wait for the result to appear (the server function should return 5)
    tokio::time::sleep(Duration::from_millis(500)).await;

    // Check that the result shows "5"
    let result_element = runner
        .driver
        .find(By::Id("server-result"))
        .await
        .context("finding server result element")?;

    let result_text = result_element.text().await.context("getting result text")?;

    assert!(
        result_text.contains('5'),
        "Server function should return 5 for 2 + 3, but got: {}",
        result_text
    );

    Ok(())
}

// ============================================================================
// Test Runner
// ============================================================================

macro_rules! run_tests {
    ($runner:expr; $( $name:literal => $test:ident ),* $(,)? ) => {{
        let test_names: &[&str] = &[$($name),*];
        let total = test_names.len();
        println!("Running {} tests...\n", total);

        let mut idx = 0;
        $(
            idx += 1;
            print!("[{}/{}] {} ... ", idx, total, $name);
            match $test($runner).await {
                Ok(()) => println!("✅"),
                Err(e) => {
                    println!("❌");
                    anyhow::bail!("Test '{}' failed: {}", $name, e);
                }
            }
        )*

        println!("\n✅ All {} tests passed!", total);
        Ok::<(), anyhow::Error>(())
    }};
}

#[tokio::main]
async fn main() -> Result<()> {
    let runner = TestRunner::new().await?;

    let result = run_tests!(&runner;
        "Main page is reachable" => test_main_page_reachable,
        "CSS link present in HTML" => test_css_link_present,
        "CSS file is accessible" => test_css_file_accessible,
        "CSS contains Tailwind classes" => test_css_contains_tailwind_classes,
        "CSS is valid Tailwind output" => test_css_is_valid_tailwind,
        "Server function section present" => test_server_function_section_present,
        "Server function executes correctly" => test_server_function_executes,
    );

    // Explicitly quit WebDriver to avoid Tokio runtime shutdown panic
    runner.quit().await?;

    result
}
