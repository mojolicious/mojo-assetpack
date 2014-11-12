/** @jsx React.DOM */

var c = require("comment-box");
var app = <div className="appClass">Hello, React!</div>;

React.renderComponent(
  <h1>Hello, world!</h1>,
  document.getElementById('example')
);
