define [
  'backbone'
  'model/sockets'
], (Backbone, sockets) ->

  # The PlayerService class provide registration facilities.
  #
  class PlayerService extends Backbone.Events

    # The router will act as a event bus.
    router: null

    # Constructs a new PlayerService instance.
    #
    # @param router [Router] the event dispatcher.
    constructor: (@router) ->
      # bind to the socket responses
      sockets.player.on 'getByLogin-resp', @_onGetByLogin
      sockets.player.on 'register-resp', @_onRegister

  return PlayerService