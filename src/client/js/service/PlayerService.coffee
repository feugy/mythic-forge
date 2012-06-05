define [
  'backbone'
  'underscore'
  'model/Player'
  'model/Item'
  'model/sockets'
], (Backbone, _, Player, Item, sockets) ->

  # The PlayerService class provide registration facilities.
  #
  class PlayerService extends Backbone.Events

    # The currently connected player.
    connected: null

    # The router will act as a event bus.
    router: null

    # Constructs a new PlayerService instance.
    #
    # @param router [Router] the event dispatcher.
    constructor: (@router) ->
      # bind to the socket responses
      sockets.player.on 'getByLogin-resp', @_onGetByLogin
      sockets.player.on 'register-resp', @_onRegister
      # bind to potential emitters
      @router.on 'register', @register
      @router.on 'authenticate', @authenticate

    # Authentication method. 
    # At the end of the authentication procedure, the `authenticated` event is triggered
    #
    # @param login [String] authenticated account credential
    authenticate: (login) =>
      console.log "try to authenticate #{login}..."
      sockets.player.emit 'getByLogin', login

    # Authentication handler. 
    # Trigger the `authenticated` event with following parameters:
    # 
    # - err [String] an error string, including the authentication failures. Null is no error occured.
    # - account [Player] the authenticated account with its character resolved. 
    #
    # @param err [String] error string. Null if no error occured
    # @param player [Player] the authenticated account.
    _onGetByLogin: (err, player) =>
      # error cases
      err = 'unknown account' if not(player?) and not(err?)
      if err?
        console.log "failed to authenticate: #{err}"
        return @router.trigger 'authenticated', err, null 

      # success
      @connected = new Player player
      console.log "authentication success for #{@connected.get 'login'}"

      @router.trigger 'authenticated', null, @connected

    # Registration method. 
    # At the end of the registration procedure, the `registered` event is triggered
    #
    # @param login [String] new account credential
    register: (login) =>
      console.log "try to register #{login}..."
      sockets.player.emit 'register', login

    # Registration handler. 
    # Trigger the `registered` event with following parameters:
    # 
    # - err [String] an error string, including the creation failures. Null is no error occured.
    # - account [Player] the created and authenticated account with its character resolved. 
    #
    # @param err [String] error string. Null if no error occured
    # @param player [Player] the created account.
    _onRegister: (err, player) =>
      # error cases
      if err?
        console.log "failed to create account: #{err}"
        return @router.trigger 'registered', err, null 

      # success
      @connected = new Player player
      console.log "registration success for #{@connected.get 'login'}"

      processResolve = _.bind (args, results) ->
        @router.off 'rulesResolved', processResolve
        # the rule has been executed.
        @router.on 'rulesExecuted', processExecute
        # execute the first creation rule
        @router.ruleService.execute results[player._id][0].name, player._id
      , @

      processExecute= _.bind (args, character) ->
        @router.off 'rulesExecuted', processExecute
        console.log "character #{character.type.name} #{character._id} created !"
        @connected.set 'character', new Item character
        @router.trigger 'registered', null, @connected
      , @

      # there are some rules to create a character
      @router.on 'rulesResolved', processResolve
      # resolve creation rules    
      @router.ruleService.resolve player._id

  return PlayerService