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
Rule = require '../model/Rule'
TurnRule = require '../model/TurnRule'
Executable = require '../model/Executable'
async = require 'async'
Item = require '../model/Item'
Field = require '../model/Field'
Player = require '../model/Player'
utils = require '../utils'
path = require 'path'
fs = require 'fs'
notifier = require('../service/Notifier').get()
logger = require('../logger').getLogger 'service'

# frequency, in seconds.
frequency = utils.confKey 'turn.frequency'

# Compute the remaining time in milliseconds before the next turn execution
#
# @return number of milliseconds before the next turn.
nextTurn= () ->
  (frequency-new Date().getSeconds()%frequency)*1000-(new Date().getMilliseconds())


# Populate the `modified` parameter array with models that have been modified.
# For items, recursively check linked items.
# Can also handle Fields and Players
#
# @param item [Object] root model that begins the analysis
# @param modified [Array] array of already modified object, concatenated with found modified objects
filterModified = (item, modified) ->
  # do not process if already known
  return if item in modified 
  # will be save if at least one path is modified
  modified.push(item) if item?.isModified()
  # do not go further if not an item
  return unless item instanceof Item
  properties = item.type.properties
  for prop, def of properties
    if def.type is 'object'
      value = item[prop]
      # recurse if needed on linked object that are resolved
      filterModified(value, modified) if value? and (typeof value) isnt 'string'
    else if def.type is 'array'
      values = item[prop]
      if values
        for value, i in values
          # recurse if needed on linked object that are resolved
          filterModified(value, modified) if value? and (typeof value) isnt 'string'

# Effectively resolve the applicable rules of the given actor at the specified coordinate.
#
# @param actor [Object] the concerned actor or Player
# @param targets [Array<Item>] array of targets the targeted item
# @param wholeRule [Boolean] true to returns the whole rule and not just name/category
# @param callback [Function] callback executed when rules where determined. Called with parameters:
# @option callback err [String] an error string, or null if no error occured
# @option callback rules [Object] applicable rules: an associated array with rule names id as key, and
# as value an array containing for each concerned target:
# - target [Object] the target
# - params [Object] the awaited parameters specification
# - category/rule [String/Object] the rule category, or the whole role (wholeRule is true)
resolve = (actor, targets, wholeRule, callback) ->
  results = {} 
  remainingTargets = 0
  
  # function called at the end of a target resolution.
  # if no target remains, the final callback is invoked.
  resolutionEnd = ->
    remainingTargets--
    callback null, results unless remainingTargets > 0

  # read all existing executables. @todo: use cached rules.
  Executable.find (err, executables) ->
    throw new Error "Cannot collect rules: #{err}" if err?

    rules = []
    # and for each of them, extract their rule.
    for executable in executables
      try 
        # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
        # and singleton (like ModuleWatcher) will be broken.
        obj = require path.relative __dirname, executable.compiledPath
        rules.push obj if obj? and(utils.isA obj, Rule) and obj.active
      catch err
        # report require errors
        err = "failed to require executable #{executable._id}: #{err}"
        logger.warn err
        return callback err

    logger.debug "#{rules.length} candidate rules"
    # evaluates the number of target. No targets ? leave immediately.
    remainingTargets = targets.length
    return callback null, results unless remainingTargets > 0

    # second part of the resolution, after the actor was resolved
    process = (err) ->
      return callback "Cannot resolve rule because actor's (#{actor._id}) linked item cannot be resolve: #{err}" if err?

      # process all targets in parallel.
      for target in targets
        # third part of the resolution, after target have been resolved
        process2 = (err) ->
          return callback "Cannot resolve rule because target's (#{target._id}) linked item cannot be resolve: #{err}" if err?

          # function applied to filter rules that apply to the current target.
          filterRule = (rule, end) -> 
            try
              rule.canExecute actor, target, (err, parameters) ->
                # exit at the first resolution error
                return callback "Failed to resolve rule #{rule.name}: #{err}" if err?
                if Array.isArray parameters
                  logger.debug "rule #{rule.name} applies"
                  if wholeRule
                    result = rule: rule
                  else
                    result = category: rule.category
                  result.target = target
                  result.params = parameters
                  results[rule.name] = [] unless rule.name of results
                  results[rule.name].push result 
                end() 
            catch err
              # exit at the first resolution error
              return callback "Failed to resolve rule #{rule.name}. Received exception #{err}"
          
          # resolve all rules for this target.
          async.forEach rules, filterRule, resolutionEnd
                  
        # resolve items, but not fields
        if target instanceof Item
          target.getLinked process2
        else 
          process2 null

    # resolve actor, but not player
    if actor instanceof Item
      actor.getLinked process
    else 
      process null

# Regular expression to extract dependencies from rules
depReg = /(.*)\s=\srequire\((.*)\);\n/

# The RuleService is somehow the rule engine: it indicates which rule are applicables at a given situation 
#
# @Todo: refresh cache when executable changes... 
class _RuleService

  # RuleService constructor.
  # Gets the existing executables, and store their rules.
  constructor: ->
    # Reset the local cache
    Executable.resetAll =>
      # Trigger first turn execution
      setTimeout @triggerTurn, nextTurn(), (->), true
        
  # Exports existing rules to clients: turn rules are ignored and execute() function is not exposed.
  #
  # @param callback [Function] callback executed when rules where exported. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] exported rules, in text, indexed by rule ids.
  export: (callback) =>
    # read all existing executables. @todo: use cached rules.
    Executable.find (err, executables) =>
      throw new Error "Cannot collect rules: #{err}" if err?

      rules = {}
      readContent = (executable, done) =>
        fs.readFile executable.compiledPath, (err, content) =>
          return callback "Failed to export rules. Error while reading rule #{executable.compiledPath}: #{err}" if err?
          content = content.toString()
          if content.indexOf "})(Rule);" isnt -1
            # removes the executable part
            content = content.replace '\n    this.execute = __bind(this.execute, this);\n', '\n'

            start = content.search /\s{2}.*\.prototype\.execute\s=\sfunction\(.*\)\s\{/i
            end = content.indexOf('\n  };', start)-1

            content = content.substring(0, start)+content.substring end+6
            # gets the required dependencies
            deps = []
            vars = []
            while -1 isnt content.search depReg
              # removes the require directive and extract relevant variable and path
              content = content.replace depReg, (str, variable, dep)->
                deps.push dep.replace /^'\.\.\//, "'"
                vars.push variable
                return ''
              # removes also the scope declaration
              content = content.replace " #{vars[vars.length-1]},", ''

            # replace module.exports by return
            content = content.replace 'module.exports =', 'return'
            
            # adds the define part
            content = "define('#{executable._id}', [#{deps.join ','}], function(#{vars.join ','}){\n#{content}\n});"
            
            # and keep the remaining code
            rules[executable._id] = content 
          done()

      # read content of all existing executables
      async.forEach executables, readContent, (err) =>
        callback err, rules
        
  # Resolves the applicable rules for a given situation.
  #
  # @overload resolve(playerId, callback)
  #   Resolves applicable rules at for a player
  #   @param playerId [ObjectId] the concerned player's id
  #
  # @overload resolve(actorId, x, y, callback)
  #   Resolves applicable rules at a specified coordinate
  #   @param actorId [ObjectId] the concerned actor's id
  #   @param x [Number] the targeted x coordinate
  #   @param y [Number] the targeted y coordinate
  #
  # @overload resolve(actorId, targetId, callback)
  #   Resolves applicable rules at for a specific target
  #   @param targetId [ObjectId] the targeted item's id
  #
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] applicable rules: an associated array with rule names id as key, and
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
        resolve player, [player], false, callback
    else if args.length is 2
      # actorId and targetId are specified. Retrieve corresponding items
      actorId = args[0]
      targetId = args[1]
      Item.find {$or:[{_id: actorId},{_id: targetId}]}, (err, results) =>
        return callback "Cannot resolve rules. Failed to retrieve actor (#{actorId}) or target (#{targetId}): #{err}" if err?
        actor = result for result in results when result._id.equals actorId
        target = result for result in results when result._id.equals targetId
        return callback "No actor with id #{actorId}" unless actor?
        return callback "No target with id #{targetId}" unless target?
        # at last, resolve rules.
        logger.debug "resolve rules for actor #{actorId} and #{targetId}"
        resolve actor, [target], false, callback
    else if args.length is 3 
      actorId = args[0]
      x = args[1]
      y = args[2]
      # targets must be resolved with a query.
      Item.find {$or:[{_id: actorId},{x: x, y:y}]}, (err, results) =>
        return callback "Cannot resolve rules. Failed to retrieve actor (#{actorId}) or items at position x:#{x} y:#{y}: #{err}" if err?
        actor = null
        for result,i in results 
          if result._id.equals actorId
            actor = result
            results.splice i, 1
            break
        return callback "No actor with id #{actorId}" unless actor?
        return callback "Cannot resolve rules for actor #{actorId} on map if it does not have a map !" unless actor.map?
        # Gets also field at the coordinate
        Field.findOne {mapId: actor.map._id, x:x, y:y}, (err, field) =>
          return callback "Cannot resolve rules. Failed to retrieve field at position x:#{x} y:#{y}: #{err}" if err?
          results.splice 0, 0, field if field?
          logger.debug "resolve rules for actor #{actorId} at x:#{x} y:#{y}"
          resolve actor, results, false, callback
    else 
      throw new Error "resolve() must be call with player id or actor and target ids, or actor id and coordinates"

  # Execute a particular rule for a given situation.
  # As a first validation, the rule is resolved for the target.
  # All objects modified by the rule will be registered in database.
  #
  # @param ruleName [String] the executed rule name
  #
  # @overload execute(ruleName, playerId, callback)
  #   Executes a specific rule for a player
  #   @param playerId [ObjectId] the concerned player's id
  #
  # @overload resolve(ruleName, actorId, targetId, callback)
  #   Executes a specific rule for an actor and a given target
  #   @param actorId [ObjectId] the concerned actor's id
  #   @param targetId [ObjetId] the targeted item
  #
  # @param parameters [Array] array of awaited rule parameters
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback results [Object] arbitrary object returned by rule execution
  #
  execute: (ruleName, args..., parameters, callback) =>
    actor = null
    target = null
    # second part of the process
    process = =>
      logger.debug "execute rule #{ruleName} of #{actor._id} for #{target._id}"
      # then resolve rules
      resolve actor, [target], true, (err, rules) =>
        # if the rule does not apply, leave right now
        return callback "Cannot resolve rule #{ruleName}: #{err}" if err?
        applicable = null
        applicable = _.find rules[ruleName], (obj) -> target.equals obj.target if ruleName of rules
        unless applicable? 
          return callback "The rule #{ruleName} of #{actor._id} does not apply any more for #{target._id}"
        rule = applicable.rule
        err = utils.checkParameters parameters, applicable.params
        return callback "Invalid parameters for #{ruleName}: #{err}" if err?

        # reinitialize creation and removal arrays.
        rule.saved = []
        rule.removed = []
        # otherwise, execute the rule
        try 
          rule.execute actor, target, parameters, (err, result) => 
            return callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{err}" if err?

            saved = []
            # removes objects from mongo
            logger.debug "remove model #{item._id}" for item in rule.removed
            async.forEach rule.removed, ((item, end) -> item.remove (err)-> end err), (err) => 
              return callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{err}" if err?
              # adds new objects to be saved
              saved = saved.concat rule.saved
              # looks for modified linked objects
              filterModified actor, saved
              filterModified target, saved
              # saves the whole in MongoDB
              logger.debug "save modified model #{item._id}" for item in saved
              async.forEach saved, ((item, end) -> item.save (err)-> end err), (err) => 
                return callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{err}" if err?
                # everything was fine
                callback(null, result)
        catch exc
          callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{exc}"

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
      # actorId and targetId are specified. Retrieve corresponding items
      Item.find {$or:[{_id: actorId},{_id: targetId}]}, (err, results) =>
        return callback "Cannot execute rule. Failed to retrieve actor (#{actorId}) or target (#{targetId}): #{err}" if err?
        actor = result for result in results when result._id.equals actorId
        target = result for result in results when result._id.equals targetId
        return callback "No actor with id #{actorId}" unless actor?

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
      throw new Error 'execute() must be call with player id or actor and target ids'
 
  # Trigger a turn by executing turn rules
  #
  # @param callback [Function] Callback invoked at the end of the turn execution, with one parameter:
  # @option callback err [String] an error string. Null if no error occured.
  # @param _auto [Boolean] **private** used to distinguish manual and automatic turn execution
  triggerTurn: (callback, _auto = false) =>
    logger.debug 'triggers turn rules...'
    notifier.notify 'turns', 'begin'
    
    # read all existing executables. @todo: use cached rules.
    Executable.find (err, executables) =>
      throw new Error "Cannot collect rules: #{err}" if err?

      rules = []
      # and for each of them, extract their turn rule.
      for executable in executables
        try
          # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
          # and singleton (like ModuleWatcher) will be broken.
          obj = require path.relative __dirname, executable.compiledPath
          rules.push obj if obj? and utils.isA(obj, TurnRule)
        catch err
          # report require errors
          err = "failed to require executable #{executable._id}: #{err}"
          logger.warn err
          notifier.notify 'turns', 'error', executable._id, err

      # sort rules by rank
      rules.sort (a, b) -> a.rank - b.rank

      # function that updates dbs with rule's modifications
      updateDb = (rule, saved, removed, end) =>
        # at the end, save and remove modified items
        removeModel = (target, removeEnd) =>
          logger.debug "remove model #{target._id}"
          target.remove (err) =>
            # stop a first execution error.
            removeEnd if err? then "Failed to remove model #{target._id} at the end of the turn: #{err}" else undefined
        # first removals
        async.forEach removed, removeModel, => 
          saveModel = (target, saveEnd) =>
            logger.debug "save model #{target._id}"
            target.save (err) =>
              # stop a first execution error.
              saveEnd if err? then "Failed to save model #{target._id} at the end of the turn: #{err}" else undefined
          # then saves
          async.forEach saved, saveModel, (err) =>
            if err?
              logger.warn err
              notifier.notify 'turns', 'failure', rule.name, err
              return end()
            notifier.notify 'turns', 'success', rule.name
            end()

      # function that select target of a rule and execute it on them
      selectAndExecute = (rule, end) =>
        # ignore disabled rules
        return end() unless rule.active
        notifier.notify 'turns', 'rule', rule.name

        try
          rule.select (err, targets) =>
            # Do not emit an error, but stops this rule a first selection error.
            if err?
              err = "failed to select targets for rule #{rule.name}: #{err}"
              logger.warn err
              notifier.notify 'turns', 'failure', rule.name, err
              return end()
            return end() unless Array.isArray(targets)
            logger.debug "rule #{rule.name} selected #{targets.length} target(s)"
            # arrays of modified objects
            saved = []
            removed = []

            # function that execute the current rule on a target
            execute = (target, executeEnd) =>
              try
                rule.execute target, (err) =>
                  # stop a first execution error.
                  return executeEnd "failed to execute rule #{rule.name} on target #{target._id}: #{err}" if err?
                  # store modified object for later
                  saved.push obj for obj in rule.saved
                  filterModified target, saved
                  removed.push obj for obj in rule.removed
                  executeEnd()
              catch err
                # stop a first execution error.
                return executeEnd "failed to execute rule #{rule.name} on target #{target._id}: #{err}"         

            # execute on each target and leave at the end.
            async.forEach targets, execute, (err) =>
              if err?
                logger.warn err
                notifier.notify 'turns', 'failure', rule.name, err
                return end()
              # save all modified and removed object after the rule has executed
              updateDb rule, saved, removed, end

        catch err
          err = "failed to select targets for rule #{rule.name}: #{err}"
          logger.warn err
          notifier.notify 'turns', 'failure', rule.name, err
          return end()

      # select and execute each turn rule, NOT in parallel !
      async.forEachSeries rules, selectAndExecute, => 
        logger.debug 'end of turn'
        notifier.notify 'turns', 'end'
        # trigger the next turn
        setTimeout @triggerTurn, nextTurn(), callback, true if _auto
        # return callback
        callback null

class RuleService
  _instance = undefined
  @get: ->
    _instance ?= new _RuleService()

module.exports = RuleService