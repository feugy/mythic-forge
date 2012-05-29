(function() {

  define(['lib/socket.io'], function(io) {
    var origin;
    origin = ('' + window.location).replace(window.location.pathname, '');
    return {
      game: io.connect("" + origin + "/game"),
      updates: io.connect("" + origin + "/updates")
    };
  });

}).call(this);
