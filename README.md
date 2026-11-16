# KH Computer Use

Original MIT-licensed Windows desktop MCP server and portable agent skill.
Designed for Codex, Claude Desktop, Claude Code, Cursor, and other local MCP clients.
Not affiliated with OpenAI; contains no code copied from the proprietary Computer Use plugin.

## Install

Requires Windows 10/11, an unlocked interactive desktop, Node.js 20+, and Windows PowerShell 5.1.
Extract or clone this project to a permanent folder, then run `npm ci` there.
Use the absolute path to `server.mjs` in the configurations below.

### Claude Desktop and Cursor

Merge this entry into `mcpServers` in Claude Desktop's `%APPDATA%/Claude/claude_desktop_config.json`
or Cursor's `%USERPROFILE%/.cursor/mcp.json`. Replace the example path.

```json
{
  "mcpServers": {
    "kh-computer-use": {
      "command": "node",
      "args": ["C:/path/to/kh-computer-use/server.mjs"],
      "env": { "KH_COMPUTER_USE_ALLOW_INPUT": "1" }
    }
  }
}
```

### Codex

```powershell
codex mcp add kh-computer-use --env KH_COMPUTER_USE_ALLOW_INPUT=1 -- node C:/path/to/kh-computer-use/server.mjs
```

### Claude Code

```powershell
claude mcp add --transport stdio --env KH_COMPUTER_USE_ALLOW_INPUT=1 kh-computer-use -- node C:/path/to/kh-computer-use/server.mjs
```

Restart the client after configuration. Confirm that six tools appear.
Omit the environment variable or set it to `0` to allow only screenshots and window discovery.
Copy `skills/kh-computer-use` into a client's supported skill directory, or provide its SKILL.md as agent instructions.
Other AI applications need an MCP client that supports local stdio servers and image tool results.

## Tools

| Tool | Purpose |
| --- | --- |
| list_windows | Visible titled windows and handles |
| screenshot | PNG of the visible virtual desktop and pixel bounds |
| focus_window | Restore and focus an existing window |
| click | Single left/right click at absolute desktop coordinates |
| type_text | Literal Unicode text with Windows SendInput |
| press_key | Named key or a supported shortcut |

Input tools are disabled by default. Enabling input permits changes in foreground applications.
There is no remote listener or arbitrary shell execution tool. Data from tools is passed as base64 JSON, not interpolated script.
Screen content is returned to the connected AI client. The server does not save screenshots.
Use one controlling agent at a time: separate client processes share the same physical desktop.
Windows may reject input to elevated apps. Locked sessions, secure desktops, and occluded-window capture are unsupported.
No UI accessibility tree, scrolling, dragging, or browser DOM tools are included in this first release.

## Verification

Run `npm test`. The integration test checks a real MCP handshake, tool discovery, native window listing,
a PNG screenshot, schema rejection, and the default input gate. It does not send mouse or keyboard input.
Live operation in each supported AI application requires a separate acceptance check.

## Share and publish

The source is MIT licensed. Share the ZIP or upload this folder to your GitHub repository, excluding node_modules.
Recipients run `npm ci` and configure their own local client. A cloud-hosted AI cannot control this desktop
unless it has an appropriate local MCP bridge; this package does not create that bridge.

Reference documentation:
- https://github.com/modelcontextprotocol/typescript-sdk
- https://developers.openai.com/codex/mcp/
- https://code.claude.com/docs/en/mcp
- https://modelcontextprotocol.io/quickstart/user
- https://docs.cursor.com/context/model-context-protocol
