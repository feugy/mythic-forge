###
  Copyright 2010~2014 Damien Feugas
  
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
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

_ = require 'underscore'
async = require 'async'
{relative} = require 'path'
Rule = require '../../model/Rule'
Executable = require '../../model/Executable'
Item = require '../../model/Item'
Event = require '../../model/Event'
Field = require '../../model/Field'
Player = require '../../model/Player'
Map = require '../../model/Map'
{type, isA, fromRule} = require '../../util/common'
utils = require '../../util/model'
{notifCampaigns} = require '../../util/rule'
logger = require('../../util/logger').getLogger 'executor'

# Effectively resolve the applicable rules of the given actor at the specified coordinate.
#
# @param actor [Object] the concerned actor or Player
# @param targets [Array<Item/Event>] array of targets the targeted item and event
# @param wholeRule [Boolean] true to returns the whole rule and not just id/category
# @param worker [Object] current object on which _errMsg is set for unexpected errors
# @param restriction [Array<String>|String] restrict resolution to a given categories or ruleId. 
# If an array, only rule that match one of the specified category is resolved.
# If a single string, only rule that has this id is resolved.
# Otherwise all rules are resolved.
# @param current [Player] currently connected player
# @param callback [Function] callback executed when rules where determined. Called with parameters:
# @option callback err [String] an error string, or null if no error occured
# @option callback rules [Object] applicable rules: an associated array with rule id as key, and
# as value an array containing for each concerned target:
# - target [Object] the target
# - params [Object] the awaited parameters specification
# - category [String] the rule category
internalResolve = (actor, targets, wholeRule, worker, restriction, current, callback) ->
  results = {}
  remainingTargets = 0
  
  # read all existing executables. @todo: use cached rules.
  Executable.find (err, executables) ->
    throw new Error "Cannot collect rules: #{err}" if err?
    rules = []
    # and for each of them, extract their rule.
    for executable in executables
      try 
        # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
        # and singleton (like ModuleWatcher) will be broken.
        obj = require relative __dirname, executable.compiledPath
        obj?.id = executable.id
        obj?.category = '' unless 'string' is type obj?.category
        if obj? and isA(obj, Rule) and obj.active
          if _.isArray restriction
            rules.push obj if obj.category in restriction
          else if _.isString restriction
            rules.push obj if obj.id is restriction
          else
            rules.push obj
      catch err
        # report require errors
        err = "failed to require executable #{executable.id}: #{err}"
        logger.warn err
        return callback err

    logger.debug "#{rules.length} candidate rules"
    # No targets ? leave immediately.
    return callback null, results unless targets.length > 0

    # second part of the resolution, after the actor was resolved
    process = (err) ->
      return callback "Cannot resolve rule because actor's (#{actor.id}) linked item/event cannot be resolve: #{err}" if err?

      # first, resolve all targets
      async.map targets, (target, next) ->
        # resolve items and events, but not fields
        if target instanceof Item or target instanceof Event
          target.fetch next
        else 
          next null, target
      , (err, targets) ->
        return callback "Cannot resolve rule because target's linked item/event cannot be resolve: #{err}" if err?
        # process all resolved targets in parallel.
        async.each targets, (target, nextTarget) ->
          # resolve all rules for this target.
          async.each rules, (rule, nextRule) -> 
            # message used in case of uncaught exception
            worker._errMsg = "Failed to resolve rule #{rule.id}. Received exception "

            rule.canExecute actor, target, {player: current}, (err, parameters) ->
              # exit at the first resolution error
              return nextRule "Failed to resolve rule #{rule.id}. Received exception #{err}" if err?
              if Array.isArray parameters
                logger.debug "rule #{rule.id} applies"
                if wholeRule
                  result = rule: rule
                else
                  # do not send fully fetched target: it may contained reference to actor and then cause a stack explosion
                  if target?._className in ['Event', 'Item']
                    utils.processLinks target, target.type.properties, false
                  result = category: rule.category
                result.target = target
                result.params = parameters
                results[rule.id] = [] unless rule.id of results
                results[rule.id].push result 
              nextRule()
          , nextTarget
        , (err) ->
          # final callback
          callback err, results

    # resolve actor, but not player
    if actor instanceof Item
      actor.fetch process
    else 
      process null

module.exports = 

  # Resolves the applicable rules for a given situation.
  #
  # @overload resolve(playerId, restriction, email, callback)
  #   Resolves applicable rules at for a player
  #   @param playerId [ObjectId] the concerned player id
  #
  # @overload resolve(actorId, x, y, restriction, email, callback)
  #   Resolves applicable rules at a specified coordinate
  #   @param actorId [ObjectId] the concerned item id
  #   @param x [Number] the targeted x coordinate
  #   @param y [Number] the targeted y coordinate
  #
  # @overload resolve(actorId, targetId, restriction, email, callback)
  #   Resolves applicable rules at for a specific target
  #   @param actorId [ObjectId] the concerned item/player id
  #   @param targetId [ObjectId] the targeted item/event id
  #
  # @param restriction [Array<String>|String] restrict resolution to a given categories or ruleId. 
  # If an array, only rule that match one of the specified category is resolved.
  # If a single string, only rule that has this id is resolved.
  # Otherwise all rules are resolved.
  # @param email [String] email of currently connected player
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] applicable rules: an associated array with rule id as key, and
  # as value an array containing for each concerned target:
  # - target [Object] the target
  # - params [Object] the awaited parameters specification
  # - category [String] the rule category
  resolve: (args..., restriction, email, callback) =>
    return if fromRule callback
    # resolve connected player first
    Player.findOne {email: email}, (err, current) =>
      return callback "Cannot resolve rules. Failed to retrieve current player (#{email}): #{err}" if err?
      return callback "No player with email #{email}" unless current?      
      if args.length is 1
        # only playerId specified. Retrieve corresponding account
        playerId = args[0]
        Player.findOne {_id: playerId}, (err, player) =>
          return callback "Cannot resolve rules. Failed to retrieve player (#{playerId}): #{err}" if err?
          return callback "No player with id #{playerId}" unless player?      
          # at last, resolve rules.
          logger.debug "resolve rules for player #{playerId}"
          internalResolve player, [player], false, @, restriction, current, callback
      else if args.length is 2
        # actorId and targetId are specified. Retrieve corresponding items and events
        actorId = args[0]
        targetId = args[1]
        Item.find {$or:[{_id: actorId},{_id: targetId}]}, (err, results) =>
          return resolveEnd "Cannot resolve rules. Failed to retrieve actor (#{actorId}) or target (#{targetId}): #{err}" if err?
          actor = result for result in results when result.id is actorId
          target = result for result in results when result.id is targetId

          process = =>
            # at last, resolve rules.
            logger.debug "resolve rules for actor #{actorId} and #{targetId}"
            internalResolve actor, [target], false, @, restriction, current, callback

          findTarget = =>
            # target exists: resolve it
            return process() if target?
            # target could be also an event
            Event.findOne {_id: targetId}, (err, result) =>
              return callback "Cannot resolve rule. Failed to retrieve event target (#{targetId}): #{err}" if err?
              target = result
              return process() if target?
              # target could be also a field
              Field.findOne {_id: targetId}, (err, result) =>
                return callback "Cannot resolve rule. Failed to retrieve field target (#{targetId}): #{err}" if err?
                return callback "No target with id #{targetId}" unless result?
                target = result
                process()

          return findTarget() if actor?
          # actor could be a player
          Player.findOne {_id: actorId}, (err, result) =>
            return resolveEnd "Cannot resolve rules. Failed to retrieve actor (#{actorId}): #{err}" if err?
            return callback "No actor with id #{actorId}" unless result?
            actor = result
            findTarget()

      else if args.length is 3 
        actorId = args[0]
        x = args[1]
        y = args[2]
        # targets must be resolved with a query. (necessary items, because we are on map)
        Item.find {$or:[{_id: actorId},{x: x, y:y}]}, (err, results) =>
          return callback "Cannot resolve rules. Failed to retrieve actor (#{actorId}) or items at position x:#{x} y:#{y}: #{err}" if err?
          actor = null
          for result,i in results 
            if result.id is actorId
              actor = result
              # remove actor from target unless he's on the map
              results.splice i, 1 unless actor.x is x and actor.y is y
              break
          return callback "No actor with id #{actorId}" unless actor?
          return callback "Cannot resolve rules for actor #{actorId} on map if it does not have a map !" unless actor.map?
          # filters item with actor map
          results = _.filter results, (item) -> actor.map.equals item?.map
          # gets also field at the coordinate
          Field.findOne {mapId: actor.map.id, x:x, y:y}, (err, field) =>
            return callback "Cannot resolve rules. Failed to retrieve field at position x:#{x} y:#{y}: #{err}" if err?
            results.splice 0, 0, field if field?
            logger.debug "resolve rules for actor #{actorId} at x:#{x} y:#{y}"
            internalResolve actor, results, false, @, restriction, current, callback
      else 
        callback "resolve() must be call with player id or actor and target ids, or actor id and coordinates"
   
  # Execute a particular rule for a given situation.
  # As a first validation, the rule is resolved for the target.
  # All objects modified by the rule will be registered in database.
  #
  # @param ruleId [String] the executed rule id
  #
  # @overload execute(ruleId, playerId, parameters, email, callback)
  #   Executes a specific rule for a player
  #   @param playerId [ObjectId] the concerned player id
  #
  # @overload execute(ruleId, actorId, targetId, parameters, email, callback)
  #   Executes a specific rule for an actor and a given target
  #   @param actorId [ObjectId] the concerned item/player id
  #   @param targetId [ObjetId] the targeted item/event id
  #
  # @param parameters [Array] array of awaited rule parameters
  # @param email [String] email of currently connected player
  # @param callback [Function] callback executed when rule was applied. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback result [Object] object send back by the executed rule
  execute: (ruleId, args..., parameters, email, callback) =>
    return if fromRule callback
    # resolve connected player first
    Player.findOne {email: email}, (err, current) =>
      return callback "Failed to execute rule #{rule.id}. Failed to retrieve current player (#{email}): #{err}" if err?
      return callback "No player with email #{email}" unless current?   
      actor = null
      target = null
      # second part of the process
      process = =>
        logger.debug "execute rule #{ruleId} of #{actor.id} for #{target.id}"

        # then resolve rules
        internalResolve actor, [target], true, @, ruleId, current, (err, rules) =>
          # if the rule does not apply, leave right now
          return callback "Cannot resolve rule #{ruleId}: #{err}" if err?
          applicable = null
          applicable = _.find rules[ruleId], (obj) -> target.equals obj.target if ruleId of rules
          unless applicable? 
            return callback "The rule #{ruleId} of #{actor.id} does not apply any more for #{target.id}"
          rule = applicable.rule

          # reinitialize creation and removal arrays.
          rule.saved = []
          rule.removed = []
          # check parameters
          utils.checkParameters parameters, applicable.params, actor, target, (err) =>
            return callback err if err?

            # message used in case of uncaught exception
            @_errMsg = "Failed to execute rule #{rule.id} of #{actor.id} for #{target.id}:"

            rule.execute actor, target, parameters, {player: current}, (err, result) => 
              return callback "Failed to execute rule #{rule.id} of #{actor.id} for #{target.id}: #{err}" if err?
              saved = []

              # load removed ids
              ids = (id for id in rule.removed when _.isString id)
              async.eachSeries [Item, Event, Player, Field, Map], (Class, next) =>
                # no more ids
                return next() if ids.length is 0
                enrich = (err, results) =>
                  return next "Failed to execute rule #{rule.id} of #{actor.id} for #{target.id}: #{err}" if err?
                  # replace found result into rule.removed array
                  for removed in results 
                    for id, i in rule.removed when id is removed.id
                      rule.removed[i] = removed 
                      ids = _.without ids, id
                      break
                  next()

                # try to load objects from their ids
                if 'findCached' of Class
                  Class.findCached ids, enrich
                else 
                  Class.find {_id: $in: ids}, enrich
              , (err) =>
                return callback err if err?
                # removes objects from mongo (without duplicates)
                utils.purgeDuplicates rule.removed
                async.each rule.removed, (obj, end) -> 
                  logger.debug "remove #{obj._className} #{obj.id}"
                  obj.remove (err)-> end err
                , (err) => 
                  return callback "Failed to execute rule #{rule.id} of #{actor.id} for #{target.id}: #{err}" if err?
                  
                  saved = []
                  # looks for modified linked objects, for every saved object
                  utils.filterModified obj, saved for obj in [actor, target].concat rule.saved
                  # removes duplicates and sort to save new objects first
                  utils.purgeDuplicates saved
                  saved.sort (o1, o2) -> if o1.id? and not o2.id? then 1 else if o2.id? and not o1.id? then -1 else 0

                  # saves the whole in MongoDB
                  async.forEach saved, (obj, end) -> 
                    # do not re-save models that were already removed !
                    return end() if _.any rule.removed, (removed) -> removed?.equals?(obj)
                    logger.debug "save modified #{obj._className} #{obj.id}, #{obj.modifiedPaths().join(',')}"
                    obj.save end
                  , (err) => 
                    return callback "Failed to execute rule #{rule.id} of #{actor.id} for #{target.id}: #{err}" if err?
                    # everything was fine, now, send campaigns
                    return callback null, result unless rule.campaigns?

                    notifCampaigns rule.campaigns, (err, report) ->
                      if report?
                        for operation in report
                          logger.debug "sent notification to #{operation.endpoint} succeeded ? #{operation.success}"
                      callback err, result
              
      if args.length is 1
        playerId = args[0]
        return callback "Player id is null !" unless playerId?
        # only playerId specified. Retrieve corresponding account
        Player.findOne {_id: playerId}, (err, player) =>
          return callback "Cannot execute rule. Failed to retrieve player (#{playerId}): #{err}" if err?
          return callback "No player with id #{playerId}" unless player?
          actor = player
          target = player
          process()

      else if args.length is 2
        actorId = args[0]
        targetId = args[1]
        return callback "Target id is null !" unless targetId?
        return callback "Actor id is null !" unless actorId?

        # actorId and targetId are specified. Retrieve corresponding items and events
        Item.find {_id: $in: [actorId, targetId]}, (err, results) =>
          return callback "Cannot execute rule. Failed to retrieve actor (#{actorId}) or target (#{targetId}): #{err}" if err?
          actor = result for result in results when result.id is actorId
          target = result for result in results when result.id is targetId

          findTarget = =>
            # target exists: process execution
            return process() if target?
            # target could be also an event
            Event.findOne {_id: targetId}, (err, result) =>
              return callback "Cannot execute rule. Failed to retrieve event target (#{targetId}): #{err}" if err?
              target = result
              return process() if target?
              # target could be also a field
              Field.findOne {_id: targetId}, (err, result) =>
                return callback "Cannot execute rule. Failed to retrieve field target (#{targetId}): #{err}" if err?
                return callback "No target with id #{targetId}" unless result?
                target = result
                process()

          return findTarget() if actor?
          # actor could be a player
          Player.findOne {_id: actorId}, (err, result) =>
            return callback "Cannot execute rules. Failed to retrieve actor (#{actorId}): #{err}" if err?
            return callback "No actor with id #{actorId}" unless result?
            actor = result
            findTarget()

      else 
        callback 'execute() must be call with player id or actor and target ids'