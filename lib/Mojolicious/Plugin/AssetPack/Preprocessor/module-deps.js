var fs = require('fs');
var ModuleDeps = require('module-deps');
var JSONStream = require('JSONStream');
var globalTransform = [];
var cache = {};

// ASSETPACK_CACHED=file-a.js:file-b.js ASSETPACK_TRANSFORMERS='{"reactify":{}}' node ./deps ./t/public/js/react-simple.js

if (process.argv.length <= 2) {
  process.exit(1);
}
if (process.env.ASSETPACK_CACHED) {
  process.env.ASSETPACK_CACHED.split(':').forEach(function(file) {
    cache[file] = { deps: {} };
  });
}
if (process.env.ASSETPACK_TRANSFORMERS) {
  globalTransform = JSON.parse(process.env.ASSETPACK_TRANSFORMERS);
}

var md = new ModuleDeps({ cache: cache, globalTransform: globalTransform });

md.pipe(JSONStream.stringify()).pipe(process.stdout);
md.write(fs.realpathSync(process.argv[2]));
md.end();
