define [
  'lib/socket.io'
], (io) ->

  return {
    # multiplexed socket for game method RPC
    game: io.connect 'http://localhost/game'
    # broadcast socket for database updates
    updates: io.connect 'http://localhost/updates'
  }