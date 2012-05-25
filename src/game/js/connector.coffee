define ['lib/socket.io', 'lib/underscore', 'lib/backbone'], (io, _, Backbone) ->
  
  return {
    # multiplexed socket for game method RPC
    gameSocket: io.connect('http://localhost/game')

    # event dispatcher for server return methods
    dispatcher: _.clone Backbone.Events
  }