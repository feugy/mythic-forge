define [
  'socket.io'
], (io) ->
  origin = "https://#{window.location.host}"
  
  return {
    # multiplexed socket for game method RPC
    game: io.connect "#{origin}/game", {secure: true}
    # broadcast socket for database updates
    updates: io.connect "#{origin}/updates", {secure: true}
  }