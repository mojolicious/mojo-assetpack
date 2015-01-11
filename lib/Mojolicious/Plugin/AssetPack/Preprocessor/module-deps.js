var fs = require('fs');
var ModuleDeps = require('module-deps');
var JSONStream = require('JSONStream');
var transformers = {};
var cache = {};

// ASSETPACK_CACHE=/tmp/cache.js ASSETPACK_TRANSFORMERS='{"reactify":{}}' node ./deps ./t/public/js/react-simple.js

if (process.env.ASSETPACK_CACHED) {
  process.env.ASSETPACK_CACHED.split(':').forEach(function(file) {
    cache[file] = { deps: {} };
  });
}

if (process.env.ASSETPACK_TRANSFORMERS) transformers = JSON.parse(process.env.ASSETPACK_TRANSFORMERS);
if (process.argv.length <= 2) process.exit(1);

var md = new ModuleDeps({ cache: cache, globalTransform: Object.keys(transformers) });
md.pipe(JSONStream.stringify()).pipe(process.stdout);
md.write(fs.realpathSync(process.argv[2]));
md.end();
