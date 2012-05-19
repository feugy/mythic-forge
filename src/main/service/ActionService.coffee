Rule = require '../model/Rule'
Executable = require '../model/Executable'
async = require 'async'
Item = require '../model/Item'
utils = require '../utils'
logger = require('../logger').getLogger 'service'

# The ActionService is somehow the rule engine: it indicates which action are applicables at a given situation 
#
# @todo Cache the existing rules refresh the cache on Executable changes
class _ActionService

  # Resolves the applicable actions for a given situation.
  #
  # @param actor [Item] the concerned actor
  # @param callback [Function] callback executed when actions where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback actions [Object] applicable actions, stored in array and indexed with the target'id on which they apply
  #
  # @overload resolve(actor, x, y, callback)
  #   Resolves applicable actions at a specified coordinate
  #   @param x [Number] the targeted x coordinate
  #   @param y [Number] the targeted y coordinate
  #
  # @overload resolve(actor, target, callback)
  #   Resolves applicable actions at for a specific target
  #   @param target [Item] the targeted item
  resolve: (actor, args..., callback) =>
    if args.length == 1
      # target is directly specified
      logger.debug "resolve rules for actor #{actor._id} and #{args[0]._id}"
      @_resolve actor, args, callback
    else if args.length == 2 
      logger.debug "resolve rules for actor #{actor._id} at x:#{args[0]} y:#{args[1]}"
      # targets must be resolved with a query.
      Item.find {x: args[0], y:args[1]}, (err, items) =>
        return callback "Cannot resolve rules. Failed to retrieve items at position x:#{args[0]} y:#{args[1]}: #{err}" if err?
        @_resolve actor, items, callback
    else 
      throw new Error "resolve() must be call directly with a target, or with coordinates"

  # Execute a particular rule for a given situation.
  # As a first validation, the rule is resolved for the target.
  # All objects modified by the rule will be registered in database.
  #
  # @param rule [Rule] the rule executed
  # @param actor [Item] the concerned actor
  # @param target [Item] the targeted item
  # @param callback [Function] callback executed when actions where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback actions [Object] applicable actions, stored in array and indexed with the target'id on which they apply
  execute: (rule, actor, target, callback) =>
    logger.debug "execute rule #{rule.name} of #{actor._id} for #{target._id}"
    # first resolve rules
    @_resolve actor, [target], (err, actions) =>
      # if the rule does not apply, leave right now
      return callback "Cannot resolve rule #{rule.name}: #{err}" if err?
      return callback "The rule #{rule.name} of #{actor._id} does not apply any more for #{target._id}" if not rule in actions[target._id] 
      
      # otherwise, execute the rule
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
 
  # **private**
  # Return the linked items that are marked as modified.
  #
  # @param item [Item] root item that begins the analysis
  # @return an array (may be empty) of modified items
  _filterModified: (item, modified) =>
    # do not process if already known
    return if item in modified 
    # will be save if at least one path is modified
    modified.push(item) if item?.modifiedPaths?.length
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
  # Effectively resolve the applicable actions of the given actor at the specified coordinate.
  #
  # @param actor [Item] the concerned actor
  # @param targets [Array<Item>] array of targets the targeted item
  # @param callback [Function] callback executed when actions where determined. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback actions [Object] applicable actions, stored in array and indexed with the target'id on which they apply
  _resolve: (actor, targets, callback) =>
    results = {} 
    remainingTargets = 0

    # function called at the end of a target resolution.
    # if no target remains, the final callback is invoked.
    resolutionEnd = ->
      remainingTargets--
      callback null, results unless remainingTargets > 0

    # first, read all existing executables TODO: cache this for performance optimization.
    Executable.find (err, executables) ->
      return callback "Cannot resolve rules: #{err}" if err?
      # and for each of them, extract their rule.
      rules = []
      for executable in executables
        obj = require executable.compiledPath
        rules.push obj if obj? and utils.isA obj, Rule

      logger.debug "#{rules.length} candidate rules"
      # Evaluates the number of target. No targets ? leave immediately.
      remainingTargets = targets.length
      callback null, results unless remainingTargets > 0

      # Process all targets in parallel.
      for target in targets
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
            return callback "Failed to resolve rule #{rule.name}: #{err}"

        # resolve all rules for this target.
        async.forEach rules, filterRule, resolutionEnd

class ActionService
  _instance = undefined
  @get: ->
    _instance ?= new _ActionService()

module.exports = ActionService