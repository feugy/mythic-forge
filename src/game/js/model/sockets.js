(function() {

  define(['lib/socket.io'], function(io) {
    return {
      game: io.connect('http://localhost/game'),
      updates: io.connect('http://localhost/updates')
    };
  });

}).call(this);
