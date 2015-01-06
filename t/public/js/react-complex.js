var React = require('react');
var Progressbar = require('./react-progressbar');
var Progressbar2 = require('./react-progressbar.js');

React.renderComponent(
  <div><Progressbar completed={10} /></div>,
  document.getElementById('example')
);
