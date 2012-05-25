(function() {

  define(['lib/socket.io'], function(io) {
    return {
      game: io.connect('http://localhost/game')
    };
  });

}).call(this);
