import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
const base = new URL('../', import.meta.url);
test('responsive accessible parent web shell exists', () => {
 const css=readFileSync(new URL('app/globals.css',base),'utf8');
 const layout=readFileSync(new URL('app/layout.tsx',base),'utf8');
 const home=readFileSync(new URL('app/page.tsx',base),'utf8');
 assert.match(css,/width:min\(/);assert.match(css,/@media/);
 assert.match(layout,/lang="tr"/);assert.match(home,/auth-shell/);assert.match(home,/LmInput/);
});
