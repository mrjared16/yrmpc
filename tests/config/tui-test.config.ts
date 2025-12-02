import { defineConfig } from "@microsoft/tui-test";

export default defineConfig({
  // Enable tracing for debugging
  trace: true,
  
  // Test timeout - increased for YouTube API calls
  timeout: 60000,
  
  // Retry strategy for flaky tests
  retries: 1,
  
  // Expect configuration
  expect: {
    timeout: 15000, // Increased for API operations
  },
  
  // Terminal configuration - larger for better UI visibility
  terminal: {
    rows: 30,
    cols: 100,
  },
});