var React = require('react');

module.exports = React.createClass({
  render: function() {
    var w = parseInt(this.props.completed) + '%';
    return (
      <div className="progressbar-container">
        <div className="progressbar-progress" style={{width: w}} />
      </div>
    );
  }
});
