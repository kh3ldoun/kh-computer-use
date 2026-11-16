import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
test('real stdio handshake, Windows backend, validation and input gate', async () => {
 const client = new Client({name:'smoke-test',version:'1.0.0'});
 const transport = new StdioClientTransport({command:process.execPath,args:['server.mjs'],env:{...process.env,KH_COMPUTER_USE_ALLOW_INPUT:'0'}});
 try {
  await client.connect(transport);
  const {tools} = await client.listTools();
  assert.equal(tools.length,6);
  const windows = await client.callTool({name:'list_windows',arguments:{}});
  assert.ok(!windows.isError, JSON.stringify(windows));
  assert.ok(Array.isArray(JSON.parse(windows.content[0].text).windows));
  const shot = await client.callTool({name:'screenshot',arguments:{}});
  assert.ok(!shot.isError, JSON.stringify(shot).slice(0,400));
  assert.equal(shot.content[1].mimeType,'image/png');
  assert.equal(Buffer.from(shot.content[1].data,'base64').subarray(1,4).toString(),'PNG');
  const gated = await client.callTool({name:'type_text',arguments:{text:'must not be typed'}});
  assert.equal(gated.isError,true);
  assert.match(gated.content[0].text,/Input disabled/);
  const invalid = await client.callTool({name:'press_key',arguments:{key:'INVALID'}});
  assert.equal(invalid.isError,true);
 } finally { await client.close(); }
});
