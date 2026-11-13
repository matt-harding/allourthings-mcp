# AllOurThings Claude Desktop Extension

This directory contains the source metadata for the AllOurThings Claude Desktop Extension. The generated `.mcpb` archive is for **Apple Silicon Macs (M1 or later)** only.

During installation, Claude Desktop asks the user to select their existing AllOurThings vault. The extension launches the local MCP server with that selected directory; it does not create or modify the CLI configuration file.

## Build

From `allourthings-mcp`:

```bash
bun install
bun run claude-extension:build
```

The build validates the staged extension and writes the versioned archive to `packages/claude-extension/release/`. It uses macOS' built-in ZIP utility, so it does not require an additional package-manager dependency. If you have the official MCPB CLI installed (`npm install -g @anthropic-ai/mcpb`), also run `mcpb validate packages/claude-extension/build/allourthings` before submission.

Before directory submission, install the archive in Claude Desktop on a clean Apple Silicon Mac and verify the native storage addon loads without a separately installed Node runtime.

## Submission prompts

- "What appliances do I own in the kitchen?"
- "Add my Bosch washing machine, bought from John Lewis for £649 in January 2024 with a two-year warranty."
- "Find my Dyson V15 and attach its manual from this PDF URL."
