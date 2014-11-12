var i = 200;
var foo = require(  'exports-foo' );
module.exports = function (n) { return foo.fn(n * i) };
