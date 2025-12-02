// Global setup for Microsoft TUI-Test
// Ensures a stable environment for rmpc TUI tests.

export default async function globalSetup() {
  // Disable tmux-specific behavior in rmpc during tests for consistency.
  if (!process.env.RMPC_TMUX_DISABLE) {
    process.env.RMPC_TMUX_DISABLE = "1";
  }
}
