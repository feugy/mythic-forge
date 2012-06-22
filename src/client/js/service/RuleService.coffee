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
'use strict'

# Local cache of client rules.
#
cachedRules= []

define [
  'async'
  'model/sockets'
  'model/Player'
  'model/Item'
  'model/Field'
], (async, sockets, Player, Item, Field) ->

  # The RuleService class provide the rule engine on client side.
  #
  class RuleService

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
      sockets.game.on 'importRules-resp', @_onImportRules
      # bind to potential emitters
      @router.on 'resolveRules', @resolve
      @router.on 'resolveRulesLocally', @resolveLocally
      @router.on 'executeRule', @execute
      # do the initialization
      @init()

    # The initialization method retrieves all existing rules to populate the client rule engine.
    #
    init: =>
      # import all existing rules
      sockets.game.emit 'importRules'

    # Triggers rules resolution for a given actor, **on server side**.
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
        throw new Error "Can't resolve rules with arguments #{arguments}"

    # Triggers rules resolution for a given actor, **on client side**.
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
    resolveLocally: (args...) =>
      return if @_resolveArgs?
      if args.length is 1
        @_resolveArgs = 
          playerId: args[0]
        # gets the player
        player = Player.collection.get @_resolveArgs.playerId
        return console.error "Fail to resolve rules: no player with id #{@_resolveArgs.playerId}" unless player?
        console.log "locally resolve rules for player #{@_resolveArgs.playerId}"
        @_resolveInCache player, [player]

      else if args.length > 1
        # gets the actor
        @_resolveArgs = 
          actorId: args[0]
        actor = Item.collection.get @_resolveArgs.actorId
        targets = []
        return console.error "Fail to resolve rules: no actor with id #{@_resolveArgs.actorId}" unless actor?

        if args.length is 2
          # gets the target
          @_resolveArgs.targetId= args[1]
          targets.push Item.collection.get @_resolveArgs.targetId
          return console.error "Fail to resolve rules: no target with id #{@_resolveArgs.targetId}" unless targets[0]?
          console.log "locally resolve rules for #{@_resolveArgs.actorId} and target #{@_resolveArgs.targetId}"
        else if args.length is 3
          @_resolveArgs.x= args[1]
          @_resolveArgs.y= args[2]
          filter = (entity) => entity.get('x') is @_resolveArgs.x and entity.get('y') is @_resolveArgs.y
          targets = targets.concat Item.collection.filter filter
          targets = targets.concat Field.collection.filter filter
          console.log "locally resolve rules for #{@_resolveArgs.actorId} at #{@_resolveArgs.x}:#{@_resolveArgs.y}"
        else 
          throw new Error "Can't locally resolve rules with arguments #{arguments}"

        @_resolveInCache actor, targets
      else 
        throw new Error "Can't locally resolve rules with arguments #{arguments}"

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

    # Internal resolution code with local cached rules
    #
    # @param actor [Item] the concerned actor
    # @param targets [Array<Object>] fields, items and players against which rules are checked
    _resolveInCache: (actor, targets) =>
      results = {}

      # exit immediately if no target provided
      remainingTargets = targets.length
      return @_onResolveRules null, results unless remainingTargets > 0

      # function called at the end of a target resolution.
      # if no target remains, the final callback is invoked.
      resolutionEnd = =>
        remainingTargets--
        @_onResolveRules null, results unless remainingTargets > 0

      for target in targets
        # keep the target id in results
        results[target.id] = []
        
        # function applied to filter rules that apply to the current target.
        filterRule = (rule, end) ->
          try
            rule.canExecute actor, target, (err, isApplicable) ->
              # exit at the first resolution error
              return end "Failed to resolve rule #{rule.name}: #{err}" if err?
              if isApplicable
                results[target.id].push(rule) 
              end() 
          catch err
            # exit at the first resolution error
            return end "Failed to resolve rule #{rule.name}. Received exception #{err}"
        
        # resolve all rules for this target.
        async.forEach cachedRules, filterRule, resolutionEnd

    # Return handler containing client side rules.
    #
    # @param err [String] an error string. Null if no error occured
    # @param rules [Object] index array of existing rules (name as index)
    #
    _onImportRules: (err, rules) =>
      return if err?

      # error handler
      requirejs.onError = (err) =>
        console.error "failed to load rules: #{err.requireType}, #{err.requireModules}"
        # reset rules and throw an error
        cachedRules = []
        delete(requirejs.onError)
        throw new Error "Can't import rules from server"

      # compiles rules
      for name, source of rules
        eval source

        # store exported rule.
        require [name], (rule) => 
          cachedRules.push rule

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