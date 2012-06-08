###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
###

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
    # @overload resolve(playerId)
    #   Resolves applicable rules for a spacific player
    #   @param playerId [ObjectId] the player id
    #
    # @overload resolve(actorId, x, y)
    #   Resolves applicable rules at a specified coordinate
    #   @param actorId [String] the concerned actor Id
    #   @param x [Number] the targeted x coordinate
    #   @param y [Number] the targeted y coordinate
    #
    # @overload resolve(actorId, targetId)
    #   Resolves applicable rules at for a specific target
    #   @param actorId [String] the concerned actor Id
    #   @param targetId [ObjectId] the targeted item's id
    resolve: (args...) =>
      return if @_resolveArgs?
      if args.length is 1
        @_resolveArgs = 
          playerId: args[0]
        console.log "resolve rules for player #{@_resolveArgs.playerId}"
        sockets.game.emit 'resolveRules', @_resolveArgs.playerId
      else if args.length is 2
        @_resolveArgs = 
          actorId: args[0]
          targetId: args[1]
        console.log "resolve rules for #{@_resolveArgs.actorId} and target #{@_resolveArgs.targetId}"
        sockets.game.emit 'resolveRules', @_resolveArgs.actorId, @_resolveArgs.targetId
      else if args.length is 3
        @_resolveArgs = 
          actorId: args[0]
          x: args[1]
          y: args[2]
        console.log "resolve rules for #{@_resolveArgs.actorId} at #{@_resolveArgs.x}:#{@_resolveArgs.y}"
        sockets.game.emit 'resolveRules', @_resolveArgs.actorId, @_resolveArgs.x, @_resolveArgs.y
      else 
        throw new Error "Cant't resolve rules with arguments #{arguments}"

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
        console.log "rules resolution ended for #{if @_resolveArgs.actorId? then 'actor '+@_resolveArgs.actorId else 'player '+@_resolveArgs.playerId}"
        @router.trigger 'rulesResolved', @_resolveArgs, results
        # reset to allow further calls.
        @_resolveArgs = null

    # Triggers a specific rule execution for a given actor on a target
    #
    # @param ruleName [String] the rule name

    # @overload execute(ruleName, playerId)
    #   Executes rule for a player
    #   @param playerId [String] the concerned player Id
    #
    # @overload execute(ruleName, actorId, targetId)
    #   Executes rule for an actor and a target
    #   @param actorId [ObjectId] the concerned actor Id
    #   @param targetId [ObjectId] the targeted item's id
    execute: (ruleName, args...) =>
      return if @_executeArgs?
      if args.length is 1
        @_executeArgs = 
          ruleName: ruleName
          playerId: args[0]

        console.log "execute rule #{ruleName} for player #{@_executeArgs.playerId}"
        sockets.game.emit 'executeRule', ruleName, @_executeArgs.playerId

      else if args.length is 2
        @_executeArgs = 
          ruleName: ruleName
          actorId: args[0]
          targetId: args[1]
      
        console.log "execute rule #{ruleName} for #{@_executeArgs.actorId} and target #{@_executeArgs.targetId}"
        sockets.game.emit 'executeRule', ruleName, @_executeArgs.actorId, @_executeArgs.targetId
      
      else 
        throw new Error "Cant't execute rule with arguments #{arguments}"

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
        @router.trigger 'rulesExecuted', @_executeArgs, result
        # reset to allow further calls.
        @_executeArgs = null

  return RuleService