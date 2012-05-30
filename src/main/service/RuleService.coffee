Rule = require '../model/Rule'
Executable = require '../model/Executable'
async = require 'async'
Item = require '../model/Item'
Field = require '../model/Field'
utils = require '../utils'
path = require 'path'
logger = require('../logger').getLogger 'service'

# Local cache of existing rules.
# Rules are stored with their name as index.
rules = {}

# The RuleService is somehow the rule engine: it indicates which rule are applicables at a given situation 
#
# @Todo: refresh cache when executable changes... 
class _RuleService

  # RuleService constructor.
  # Gets the existing executables, and store their rules.
  constructor: ->
    # Reset the local cache
    Executable.resetAll ->

  # Resolves the applicable rules for a given situation.
  #
  # @param actorId [ObjectId] the concerned actor's id
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] applicable rules, stored in array and indexed with the target'id on which they apply
  #
  # @overload resolve(actorId, x, y, callback)
  #   Resolves applicable rules at a specified coordinate
  #   @param x [Number] the targeted x coordinate
  #   @param y [Number] the targeted y coordinate
  #
  # @overload resolve(actorId, targetId, callback)
  #   Resolves applicable rules at for a specific target
  #   @param targetId [ObjectId] the targeted item's id
  resolve: (actorId, args..., callback) =>
    if args.length is 1
      # actorId and targetId are specified. Retrieve corresponding items
      Item.find {$or:[{_id: actorId},{_id: args[0]}]}, (err, results) =>
        return callback "Cannot resolve rules. Failed to retrieve actor (#{actorId}) or target (#{args[0]}): #{err}" if err?
        # Do not use list comprehension: they remove the Mongoose proxy (but why ?)
        actor = result for result in results when result._id.equals actorId
        target = result for result in results when result._id.equals args[0]
        return callback "No actor with id #{actorId}" unless actor?
        return callback "No target with id #{args[0]}" unless target?
        # at last, resolve rules.
        logger.debug "resolve rules for actor #{actorId} and #{args[0]}"
        @_resolve actor, [target], callback
    else if args.length is 2 
      # targets must be resolved with a query.
      Item.find {$or:[{_id: actorId},{x: args[0], y:args[1]}]}, (err, results) =>
        return callback "Cannot resolve rules. Failed to retrieve actor (#{actorId}) or items at position x:#{args[0]} y:#{args[1]}: #{err}" if err?
        actor = null
        for result,i in results 
          if result._id.equals actorId
            actor = result
            results.splice i, 1
            break
        return callback "No actor with id #{actorId}" unless actor?
        return callback "Cannot resolve rules for actor #{actorId} on map if it does not have a map !" unless actor.map?
        # Gets also field at the coordinate
        Field.findOne {map: actor.map._id, x:args[0], y:args[1]}, (err, field) =>
          return callback "Cannot resolve rules. Failed to retrieve field at position x:#{args[0]} y:#{args[1]}: #{err}" if err?
          results.splice 0, 0, field if field?
          logger.debug "resolve rules for actor #{actorId} at x:#{args[0]} y:#{args[1]}"
          @_resolve actor, results, callback
    else 
      throw new Error "resolve() must be call directly with a target, or with coordinates"

  # Execute a particular rule for a given situation.
  # As a first validation, the rule is resolved for the target.
  # All objects modified by the rule will be registered in database.
  #
  # @param ruleName [String] the executed rule name
  # @param actorId [ObjetId] the concerned actor
  # @param targetId [ObjetId] the targeted item
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] applicable rules, stored in array and indexed with the target'id on which they apply
  execute: (ruleName, actorId, targetId, callback) =>
    # actorId and targetId are specified. Retrieve corresponding items
    Item.find {$or:[{_id: actorId},{_id: targetId}]}, (err, results) =>
      return callback "Cannot execute rule. Failed to retrieve actor (#{actorId}) or target (#{targetId}): #{err}" if err?
      actor = result for result in results when result._id.equals actorId
      target = result for result in results when result._id.equals targetId
      return callback "No actor with id #{actorId}" unless actor?

      # second part of the process
      process = =>
        logger.debug "execute rule #{ruleName} of #{actor._id} for #{target._id}"
        # then resolve rules
        @_resolve actor, [target], (err, rules) =>
          # if the rule does not apply, leave right now
          return callback "Cannot resolve rule #{ruleName}: #{err}" if err?
          rule = rule for rule in rules[target._id] when rule.name is ruleName
          return callback "The rule #{ruleName} of #{actor._id} does not apply any more for #{target._id}" unless rule?
          
          # reinitialize creation and removal arrays.
          rule.created = []
          rule.removed = []
          # otherwise, execute the rule
          try 
            rule.execute actor, target, (err, result) => 
              return callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{err}" if err?

              saved = []
              # removes objects from mongo
              logger.debug "remove item #{item._id}" for item in rule.removed
              async.forEach rule.removed, ((item, end) -> item.remove (err)-> end err), (err) => 
                return callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{err}" if err?
                # adds new objects to be saved
                saved = saved.concat rule.created
                # looks for modified linked objects
                @_filterModified actor, saved
                @_filterModified target, saved
                # saves the whole in MongoDB
                logger.debug "save modified item #{item._id}" for item in saved
                async.forEach saved, ((item, end) -> item.save (err)-> end err), (err) => 
                  return callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{err}" if err?
                  # everything was fine
                  callback(null, result)
          catch exc
            callback "Failed to execute rule #{rule.name} of #{actor._id} for #{target._id}: #{exc}"

      if target?
        process()
      else 
        # target could be also a field
        Field.findOne {_id: targetId}, (err, result) =>
          return callback "Cannot execute rule. Failed to retrieve field target (#{targetId}): #{err}" if err?
          return callback "No target with id #{targetId}" unless result?
          target = result
          process()

 
  # **private**
  # Return the linked items that are marked as modified.
  #
  # @param item [Item] root item that begins the analysis
  # @return an array (may be empty) of modified items
  _filterModified: (item, modified) =>
    # do not process if not an item
    return unless item instanceof Item
    # do not process if already known
    return if item in modified 
    # will be save if at least one path is modified
    modified.push(item) if item?.modified
    properties = item.type.get('properties')
    for prop, def of properties
      if def.type is 'object'
        value = item.get prop
        # recurse if needed on linked object that are resolved
        @_filterModified(value, modified) if value? and (typeof value) isnt 'string'
      else if def.type is 'array'
        values = item.get prop
        if values
          for value, i in values
            # recurse if needed on linked object that are resolved
            @_filterModified(value, modified) if value? and (typeof value) isnt 'string'


  # **private**
  # Effectively resolve the applicable rules of the given actor at the specified coordinate.
  #
  # @param actor [Item] the concerned actor
  # @param targets [Array<Item>] array of targets the targeted item
  # @param callback [Function] callback executed when rules where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] applicable rules, stored in array and indexed with the target'id on which they apply
  _resolve: (actor, targets, callback) =>
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
        # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
        # and singleton (like ModuleWatcher) will be broken.
        obj = require '.\\'+ path.relative module.filename, executable.compiledPath
        rules.push obj if obj? and utils.isA obj, Rule

      logger.debug "#{rules.length} candidate rules"
      # evaluates the number of target. No targets ? leave immediately.
      remainingTargets = targets.length
      return callback null, results unless remainingTargets > 0

      # resolve actor once.
      actor.resolve (err) ->
        return callback "Cannot resolve rule because actor's (#{actor._id}) linked item cannot be resolve: #{err}" if err?
 
        # process all targets in parallel.
        for target in targets
          # second part of the resolution, after target have been resolved
          process= (err) ->
            return callback "Cannot resolve rule because target's (#{target._id}) linked item cannot be resolve: #{err}" if err?
            results[target._id] = []

            # function applied to filter rules that apply to the current target.
            filterRule = (rule, end) ->
              try
                rule.canExecute actor, target, (err, isApplicable) ->
                  # exit at the first resolution error
                  return callback "Failed to resolve rule #{rule.name}: #{err}" if err?
                  if isApplicable
                    logger.debug "rule #{rule.name} applies"
                    results[target._id].push(rule) 
                  end() 
              catch err
                # exit at the first resolution error
                return callback "Failed to resolve rule #{rule.name}. Received exception #{err}"
            
            # resolve all rules for this target.
            async.forEach rules, filterRule, resolutionEnd
                    
          # resolve items, but not fields
          if target.resolve
            target.resolve process
          else 
            process null

class RuleService
  _instance = undefined
  @get: ->
    _instance ?= new _RuleService()

module.exports = RuleService