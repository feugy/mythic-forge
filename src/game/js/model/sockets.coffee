define [
  'lib/socket.io'
], (io) ->

  return {
    # multiplexed socket for game method RPC
    game: io.connect('http://localhost/game')
  }