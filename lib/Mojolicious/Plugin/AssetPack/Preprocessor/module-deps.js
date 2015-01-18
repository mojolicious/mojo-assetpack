var fs = require('fs');
var ModuleDeps = require('module-deps');
var JSONStream = require('JSONStream');
var globalTransform = [];
var changed = false;
var entry;

if (process.argv.length <= 2) {
  process.exit(1);
}

if (process.env.MODULE_DEPS_TRANSFORMERS) {
  globalTransform = JSON.parse(process.env.MODULE_DEPS_TRANSFORMERS);
}

var md = new ModuleDeps({
  cache: {},
  globalTransform: globalTransform,
  postFilter: function(id, file, pkg) {
    if (changed && !changed[file]) md.cache[file] = { deps: {} };
    return true;
  }
});

entry = fs.realpathSync(process.argv[2]);
md.pipe(JSONStream.stringify()).pipe(process.stdout);
md.write(entry);

if (process.argv.length > 3) {
  changed = {};
  changed[entry] = 1;
  process.argv.slice(3).forEach(function(file) {
    file = fs.realpathSync(file);
    changed[file] = 1;
    md.write(file);
  });
}

md.end();
