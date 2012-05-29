define [
  'lib/socket.io'
], (io) ->
  origin = (''+window.location).replace window.location.pathname, ''
  
  return {
    # multiplexed socket for game method RPC
    game: io.connect "#{origin}/game"
    # broadcast socket for database updates
    updates: io.connect "#{origin}/updates"
  }