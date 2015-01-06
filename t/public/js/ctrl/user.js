var robot = [require('../robot'), 'foo']; // test require regex in Processor.pm
console.log(require('../robot'), 'foo');
console.log(robot[0]('user'));
