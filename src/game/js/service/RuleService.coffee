define [
  'lib/backbone'
  'model/sockets'
], (Backbone, sockets) ->

  # The RuleService class provide the rule engine on client side.
  #
  class RuleService extends Backbone.Events

    # The router will act as a event bus.
    router: null

    # **private**
    # Object that store resolution original parameters. Also avoid multiple concurrent server call.
    _resolveArgs: null

    # Constructs a new RuleService instance.
    #
    # @param router [Router] the event dispatcher.
    constructor: (@router) ->
      # bind to the socket responses
      sockets.game.on 'resolveRules-resp', @_onResolveRules
      # bind to potential emitters
      @router.on 'resolveRules', @resolve

    # Triggers rules resolution for a given actor
    #
    # @param actorId [String] the concerned actor Id
    #
    # @overload resolve(actorId, x, y)
    #   Resolves applicable rules at a specified coordinate
    #   @param x [Number] the targeted x coordinate
    #   @param y [Number] the targeted y coordinate
    #
    # @overload resolve(actorId, targetId)
    #   Resolves applicable rules at for a specific target
    #   @param targetId [ObjectId] the targeted item's id
    resolve: (actorId, args...) =>
      return if @_resolveArgs?
      if args.length is 2
        @_resolveArgs = 
          actorId: actorId
          x: args[0]
          y: args[1]
        console.log "resolve rules for #{actorId} at #{@_resolveArgs.x}:#{@_resolveArgs.y}"
        sockets.game.emit 'resolveRules', actorId, @_resolveArgs.x, @_resolveArgs.y
      else 
        @_resolveArgs = 
          actorId: actorId
          targetId: args[0]
        console.log "resolve rules for #{actorId} and target #{@_resolveArgs.targetId}"
        sockets.game.emit 'resolveRules', actorId, @_resolveArgs.targetId

    # Rules resolution handler. 
    # trigger an event `rulesResolved` on the router if success.
    #
    # @param err [String] an error string, or null if no error occured
    # @param results [Object] applicable rules, stored in array and indexed with the target'id on which they apply
    _onResolveRules: (err, results) =>
      if @_resolveArgs
        if err?
          @_resolveArgs = null
          return console.err "Fail to resolve rules: #{err}" 
        console.log "rules resolution ended for actor #{@_resolveArgs.actorId}"
        @router.trigger 'rulesResolved', @_resolveArgs.actorId, results

  return RuleService