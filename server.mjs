#!/usr/bin/env node
import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { z } from 'zod';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
const exec = promisify(execFile);
const backend = fileURLToPath(new URL('./desktop.ps1', import.meta.url));
const server = new McpServer({ name: 'kh-computer-use', version: '0.1.0' });
// Serialize desktop operations within this server process.
let pending = Promise.resolve();
function register(name, description, inputSchema, mutates = false) {
  server.registerTool(name, { description, inputSchema, annotations: { readOnlyHint: !mutates, destructiveHint: mutates, openWorldHint: true } }, async args => {
    const run = async () => {
      try {
        if (process.platform !== 'win32') throw new Error('Requires an interactive Windows desktop.');
        if (mutates && process.env.KH_COMPUTER_USE_ALLOW_INPUT !== '1') throw new Error('Input disabled. Set KH_COMPUTER_USE_ALLOW_INPUT=1 in the MCP launch configuration and restart.');
        const payload = Buffer.from(JSON.stringify({ action: name, ...args }), 'utf8').toString('base64');
        const { stdout } = await exec('powershell.exe', ['-NoProfile', '-NonInteractive', '-STA', '-File', backend, '-Payload', payload], { windowsHide: true, timeout: 30000, maxBuffer: 24 * 1024 * 1024 });
        const result = JSON.parse(stdout.replace(/^\uFEFF/, '').trim());
        if (result.image) return { content: [{ type: 'text', text: JSON.stringify(result.bounds) }, { type: 'image', data: result.image, mimeType: 'image/png' }] };
        return { content: [{ type: 'text', text: JSON.stringify(result) }] };
      } catch (error) { return { isError: true, content: [{ type: 'text', text: error.message }] }; }
    };
    const result = pending.then(run, run);
    pending = result.catch(() => {});
    return result;
  });
}
register('list_windows', 'List visible titled Windows application windows with their numeric handles. Use these handles to focus an existing application before sending input.', {});
register('screenshot', 'Capture the visible Windows virtual desktop as a PNG image. Returns absolute desktop bounds; mouse coordinates use these original pixels, including negative monitor origins.', {});
register('focus_window', 'Bring an existing visible application window to the foreground using a handle returned by list_windows. Returns an error if Windows refuses focus.', { handle: z.string().regex(/^\d+$/).describe('Decimal window handle from list_windows, for example 123456.') }, true);
register('click', 'Click a visible desktop position using absolute screen pixels from screenshot. Take a fresh screenshot first and verify the result afterward.', { x: z.number().int().describe('Absolute desktop X coordinate; may be negative on secondary monitors.'), y: z.number().int().describe('Absolute desktop Y coordinate; may be negative.'), button: z.enum(['left', 'right']).default('left').describe('Mouse button to click once.') }, true);
register('type_text', 'Type literal Unicode text into the currently focused control without using the clipboard. Text is entered literally; it is never evaluated as a script.', { text: z.string().min(1).max(4000).describe('Literal text to enter in the focused field, maximum 4000 characters.') }, true);
register('press_key', 'Press one key or a supported keyboard shortcut in the foreground application. Inspect focus first; shortcuts may submit forms or change application data.', { key: z.enum(['ENTER','TAB','ESC','BACKSPACE','DELETE','UP','DOWN','LEFT','RIGHT','HOME','END','CTRL+A','CTRL+C','CTRL+V','CTRL+Z','ALT+F4']).describe('Named key or shortcut, for example TAB or CTRL+A.') }, true);
await server.connect(new StdioServerTransport());
