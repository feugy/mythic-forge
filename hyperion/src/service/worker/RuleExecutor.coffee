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
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

_ = require 'underscore'
async = require 'async'
pathUtils = require 'path'
Rule = require '../../model/Rule'
Executable = require '../../model/Executable'
Item = require '../../model/Item'
Event = require '../../model/Event'
Field = require '../../model/Field'
Player = require '../../model/Player'
utils = require '../../util/common'
modelUtils = require '../../util/model'
logger = require('../../logger').getLogger 'service'

# Effectively resolve the applicable rules of the given actor at the specified coordinate.
#
# @param actor [Object] the concerned actor or Player
# @param targets [Array<Item/Event>] array of targets the targeted item and event
# @param wholeRule [Boolean] true to returns the whole rule and not just id/category
# @parma worker [Object] current object on which _errMsg is set for unexpected errors
# @param callback [Function] callback executed when rules where determined. Called with parameters:
# @option callback err [String] an error string, or null if no error occured
# @option callback rules [Object] applicable rules: an associated array with rule id as key, and
# as value an array containing for each concerned target:
# - target [Object] the target
# - params [Object] the awaited parameters specification
# - category [String] the rule category
internalResolve = (actor, targets, wholeRule, worker, callback) ->
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
        obj = require pathUtils.relative __dirname, executable.compiledPath
        obj.id = executable.id
        if obj? and(utils.isA obj, Rule) and obj.active
          rules.push obj 
          obj.id = executable.id
          obj.category = '' unless 'string' is utils.type obj.category
      catch err
        # report require errors
        err = "failed to require executable #{executable.id}: #{err}"
        logger.warn err
        return callback err

    logger.debug "#{rules.length} candidate rules"
    # evaluates the number of target. No targets ? leave immediately.
    remainingTargets = targets.length
    return callback null, results unless remainingTargets > 0

    # second part of the resolution, after the actor was resolved
    process = (err) ->
      return callback "Cannot resolve rule because actor's (#{actor.id}) linked item/event cannot be resolve: #{err}" if err?

      # process all targets in parallel.
      for target in targets
        # third part of the resolution, after target have been resolved
        process2 = (err) ->
          return callback "Cannot resolve rule because target's (#{target.id}) linked item/event cannot be resolve: #{err}" if err?

          # function applied to filter rules that apply to the current target.
          filterRule = (rule, end) -> 
            
            # message used in case of uncaught exception
            worker._errMsg = "Failed to resolve rule #{rule.id}. Received exception "

            rule.canExecute actor, target, (err, parameters) ->
              # exit at the first resolution error
              return callback "Failed to resolve rule #{rule.id}. Received exception #{err}" if err?
              if Array.isArray parameters
                logger.debug "rule #{rule.id} applies"
                if wholeRule
                  result = rule: rule
                else
                  result = category: rule.category
                result.target = target
                result.params = parameters
                results[rule.id] = [] unless rule.id of results
                results[rule.id].push result 
              end()
          
          # resolve all rules for this target.
          async.forEach rules, filterRule, ->
            # if no target remains, the final callback is invoked.
            remainingTargets--
            callback null, results unless remainingTargets > 0
                  
        # resolve items and events, but not fields
        if target instanceof Item or target instanceof Event
          target.getLinked process2
        else 
          process2 null

    # resolve actor, but not player
    if actor instanceof Item
      actor.getLinked process
    else 
      process null

module.exports = 

  # Resolves the applicable rules for a given situation.
  #
  # @overload resolve(playerId)
  #   Resolves applicable rules at for a player
  #   @param playerId [ObjectId] the concerned player's id
  #
  # @overload resolve(actorId, x, y)
  #   Resolves applicable rules at a specified coordinate
  #   @param actorId [ObjectId] the concerned actor's id
  #   @param x [Number] the targeted x coordinate
  #   @param y [Number] the targeted y coordinate
  #
  # @overload resolve(actorId, targetId)
  #   Resolves applicable rules at for a specific target
  #   @param targetId [ObjectId] the targeted item/event's id
  #
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] applicable rules: an associated array with rule id as key, and
  # as value an array containing for each concerned target:
  # - target [Object] the target
  # - params [Object] the awaited parameters specification
  # - category [String] the rule category
  resolve: (args..., callback) =>
    if args.length is 1
      # only playerId specified. Retrieve corresponding account
      playerId = args[0]
      Player.findOne {_id: playerId}, (err, player) =>
        return callback "Cannot resolve rules. Failed to retrieve player (#{playerId}): #{err}" if err?
        return callback "No player with id #{playerId}" unless player?      
        # at last, resolve rules.
        logger.debug "resolve rules for player #{playerId}"
        internalResolve player, [player], false, @, callback
    else if args.length is 2
      # actorId and targetId are specified. Retrieve corresponding items and events
      actorId = args[0]
      targetId = args[1]
      Item.find {$or:[{_id: actorId},{_id: targetId}]}, (err, results) =>
        return resolveEnd "Cannot resolve rules. Failed to retrieve actor (#{actorId}) or target (#{targetId}): #{err}" if err?
        actor = result for result in results when result.id is actorId
        target = result for result in results when result.id is targetId
        return callback "No actor with id #{actorId}" unless actor?

        process = =>
          # at last, resolve rules.
          logger.debug "resolve rules for actor #{actorId} and #{targetId}"
          internalResolve actor, [target], false, @, callback

        if target?
          process()
        else 
          # target could be also an event
          Event.findOne {_id: targetId}, (err, result) =>
            return callback "Cannot resolve rule. Failed to retrieve event target (#{targetId}): #{err}" if err?
            target = result
            if target?
              process()
            else
              # target could be also a field
              Field.findOne {_id: targetId}, (err, result) =>
                return callback "Cannot resolve rule. Failed to retrieve field target (#{targetId}): #{err}" if err?
                return callback "No target with id #{targetId}" unless result?
                target = result
                process()

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
          internalResolve actor, results, false, @, callback
    else 
      callback "resolve() must be call with player id or actor and target ids, or actor id and coordinates"
   
  # Execute a particular rule for a given situation.
  # As a first validation, the rule is resolved for the target.
  # All objects modified by the rule will be registered in database.
  #
  # @param ruleId [String] the executed rule id
  #
  # @overload execute(ruleId, playerId, callback)
  #   Executes a specific rule for a player
  #   @param playerId [ObjectId] the concerned player's id
  #
  # @overload resolve(ruleId, actorId, targetId, callback)
  #   Executes a specific rule for an actor and a given target
  #   @param actorId [ObjectId] the concerned actor's id
  #   @param targetId [ObjetId] the targeted item or event
  #
  # @param parameters [Array] array of awaited rule parameters
  # @param callback [Function] callback executed when rule was applied. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback result [Object] object send back by the executed rule
  execute: (ruleId, args..., parameters, callback) =>
    actor = null
    target = null
    # second part of the process
    process = =>
      logger.debug "execute rule #{ruleId} of #{actor.id} for #{target.id}"

      # then resolve rules
      internalResolve actor, [target], true, @, (err, rules) =>
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
        modelUtils.checkParameters parameters, applicable.params, actor, target, (err) =>
          return callback "Invalid parameter for #{rule.id}: #{err}" if err?

          # message used in case of uncaught exception
          @_errMsg = "Failed to execute rule #{rule.id} of #{actor.id} for #{target.id}:"

          rule.execute actor, target, parameters, (err, result) => 
            return callback "Failed to execute rule #{rule.id} of #{actor.id} for #{target.id}: #{err}" if err?

            saved = []
            # removes objects from mongo
            logger.debug "remove model #{obj.id}" for obj in rule.removed
            async.forEach rule.removed, ((obj, end) -> obj.remove (err)-> end err), (err) => 
              return callback "Failed to execute rule #{rule.id} of #{actor.id} for #{target.id}: #{err}" if err?
              # adds new objects to be saved
              saved = saved.concat rule.saved
              # looks for modified linked objects
              modelUtils.filterModified actor, saved
              modelUtils.filterModified target, saved
              # saves the whole in MongoDB
              logger.debug "save modified model #{obj.id}" for obj in saved
              async.forEach saved, ((obj, end) -> obj.save (err)-> end err), (err) => 
                return callback "Failed to execute rule #{rule.id} of #{actor.id} for #{target.id}: #{err}" if err?
                # everything was fine
                callback null, result

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
      Item.find {$or:[{_id: actorId},{_id: targetId}]}, (err, results) =>
        return callback "Cannot execute rule. Failed to retrieve actor (#{actorId}) or target (#{targetId}): #{err}" if err?
        actor = result for result in results when result.id is actorId
        target = result for result in results when result.id is targetId
        return callback "No actor with id #{actorId}" unless actor?
        if target?
          process()
        else 
          # target could be also an event
          Event.findOne {_id: targetId}, (err, result) =>
            return callback "Cannot execute rule. Failed to retrieve event target (#{targetId}): #{err}" if err?
            target = result
            if target?
              process()
            else
              # target could be also a field
              Field.findOne {_id: targetId}, (err, result) =>
                return callback "Cannot execute rule. Failed to retrieve field target (#{targetId}): #{err}" if err?
                return callback "No target with id #{targetId}" unless result?
                target = result
                process()

    else 
      callback 'execute() must be call with player id or actor and target ids'