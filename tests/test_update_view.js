#!/usr/bin/env node
// SPDX-License-Identifier: GPL-2.0-only
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const source = fs.readFileSync(process.env.PWM_TEST_UPDATE_VIEW || path.join(__dirname,
    '../luci-app-pwm-fan-updater/htdocs/luci-static/resources/view/system/pwm-fan/update.js'), 'utf8');
const calls = [];
const rpc = { declare: ({ method }) => (...args) => {
    calls.push([method, ...args]);
    if (method === 'channel') return Promise.resolve({ success: true, channel: 'development' });
    if (method === 'check') return Promise.reject(new Error('offline'));
    if (method === 'set_channel') return Promise.resolve({ success: true });
    throw new Error(`Unexpected RPC: ${method}`);
} };
function E(tag, attributes = {}, children = []) {
    if (Array.isArray(attributes)) { children = attributes; attributes = {}; }
    return { tag, attributes, children, value: '',
        replaceChildren(...next) { this.children = next; },
        appendChild(child) { this.children.push(child); }
    };
}
const app = new Function('rpc', 'view', 'E', '_', 'window', 'fanComponents', 'ui', source)(
    rpc, { extend: value => value }, E, value => value,
    { setTimeout() {} }, { stylesheet: () => E('style'), card: (title, child) => child }, {});
function find(node, tag) {
    if (!node || typeof node !== 'object') return null;
    if (node.tag === tag) return node;
    for (const child of node.children || []) {
        const found = find(child, tag);
        if (found) return found;
    }
    return null;
}
(async () => {
    const saved = await app.load();
    const rendered = app.render(saved);
    await new Promise(resolve => setImmediate(resolve));
    const channel = find(rendered, 'select');
    assert.equal(channel.value, 'development', 'offline check must preserve the saved channel');
    channel.value = 'stable';
    await channel.attributes.change({ currentTarget: channel });
    assert.deepEqual(calls.filter(call => call[0] === 'set_channel'), [['set_channel', 'stable']]);
    assert.equal(channel.value, 'stable');
    assert.throws(() => app.render({ success: false }), /channel|operation/i,
        'a failed channel read must not render a guessed Stable channel');
    console.log('PWM Fan update view assertions passed.');
})().catch(error => { console.error(error); process.exitCode = 1; });
