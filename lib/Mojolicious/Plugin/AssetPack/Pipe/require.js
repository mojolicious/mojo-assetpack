var modules = {};

for (var i = 2; i < process.argv.length; i++) {
  var name = process.argv[i];
  try {
    require(name);
    modules[name] = "";
  } catch (err) {
    modules[name] = err.code;
  }
}

console.log(JSON.stringify(modules));
