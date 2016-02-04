#!/usr/bin/env node
'use strict'

var riot    = require('riot')
var stdin   = process.stdin;
var stdout  = process.stdout;
var content = '';

stdin.resume();
stdin.setEncoding('utf8');
stdin.on('data', function (chunk) { content += chunk; });
stdin.on('end', function () { stdout.write(riot.compile(content)); });
