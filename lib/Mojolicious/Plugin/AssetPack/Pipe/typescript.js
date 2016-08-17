#!/usr/bin/env node
'use strict'

// TODO: Get these from environment, set by Pipe::TypeScript
var compilerOptions = {noImplicitAny: true};
var tss             = require('typescript-simple');

if (process.stdin.isTTY) {
  console.log('typescript-simple is installed');
  process.exit();
}

var stdin   = process.stdin;
var stdout  = process.stdout;
var content = '';

stdin.resume();
stdin.setEncoding('utf8');
stdin.on('data', function (chunk) { content += chunk; });
stdin.on('end', function () { stdout.write(tss(content, compilerOptions)); });
