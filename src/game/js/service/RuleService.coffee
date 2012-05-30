define [
  'backbone'
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

    # **private**
    # Object that store execution original parameters. Also avoid multiple concurrent server call.
    _executeArgs: null

    # Constructs a new RuleService instance.
    #
    # @param router [Router] the event dispatcher.
    constructor: (@router) ->
      # bind to the socket responses
      sockets.game.on 'resolveRules-resp', @_onResolveRules
      sockets.game.on 'executeRule-resp', @_onExecuteRule
      # bind to potential emitters
      @router.on 'resolveRules', @resolve
      @router.on 'executeRule', @execute

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
      if @_resolveArgs?
        if err?
          @_resolveArgs = null
          return console.error "Fail to resolve rules: #{err}" 
        console.log "rules resolution ended for actor #{@_resolveArgs.actorId}"
        @router.trigger 'rulesResolved', @_resolveArgs, results
        # reset to allow further calls.
        @_resolveArgs = null

    # Triggers a specific rule execution for a given actor on a target
    #
    # @param ruleName [String] the rule name
    # @param actorId [String] the concerned actor ud
    # @param targetId [ObjectId] the targeted id
    execute: (ruleName, actorId, targetId) =>
      return if @_executeArgs?
      @_executeArgs = 
        ruleName: ruleName
        actorId: actorId
        targetId: targetId
      
      console.log "execute rule #{ruleName} for #{actorId} and target #{targetId}"
      sockets.game.emit 'executeRule', ruleName, actorId, targetId

    # Rules execution handler. 
    # trigger an event `rulesExecuted` on the router if success.
    #
    # @param err [String] an error string, or null if no error occured
    # @param result [Object] the rule final result. Depends on the rule.
    _onExecuteRule: (err, result) =>
      if @_executeArgs?
        if err?
          @_executeArgs = null
          return console.error "Fail to execute rule: #{err}" 
        console.log "rule #{@_executeArgs.ruleName} successfully executed for actor #{@_executeArgs.actorId} and target #{@_executeArgs.targetId}"
        @router.trigger 'rulesResolved', @_executeArgs, result
        # reset to allow further calls.
        @_executeArgs = null

  return RuleService