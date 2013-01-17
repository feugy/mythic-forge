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
cluster = require 'cluster'
async = require 'async'
pathUtils = require 'path'
fs = require 'fs'
Rule = require '../model/Rule'
TurnRule = require '../model/TurnRule'
Executable = require '../model/Executable'
utils = require '../util/common'
notifier = require('../service/Notifier').get()
modelWatcher = require('../model/ModelWatcher').get()
logger = require('../logger').getLogger 'service'

# frequency, in seconds.
frequency = utils.confKey 'turn.frequency'

# Compute the remaining time in milliseconds before the next turn execution
#
# @return number of milliseconds before the next turn.
nextTurn= () ->
  # (frequency-new Date().getSeconds()%frequency)*1000-(new Date().getMilliseconds())

executor = null

if cluster.isMaster
  cluster.setupMaster 
    exec: pathUtils.join __dirname, '..', '..', 'lib', 'service', 'worker', 'Launcher'

  spawn = (module) ->
    worker = cluster.fork module: module

    # relaunch immediately dead worker
    worker.on 'exit', (code, signal) ->
      return if worker.suicide
      # TODO find a better way to populate executor variable. 
      executor = spawn module
      logger.info "respawn worker #{module} with pid #{executor.process.pid}"

    worker.on 'message', (data) ->
      return unless data?.event is 'change'
      # trigger the change as if it comes from the master modelWatcher
      modelWatcher.emit.apply modelWatcher, data.args
    worker

  executor = spawn 'RuleExecutor'
  logger.info "#{process.pid} spawn worker RuleExecutor with pid #{executor.process.pid}"

  # when a change is detected in master, send it to workers
  modelWatcher.on 'change', (operation, className, changes, wId) ->
    # use master pid if it comes from the master
    wId = if wId? then wId else process.pid
    for id, worker of cluster.workers when worker.process.pid isnt wId
      worker.send event: 'change', args:[operation, className, changes, wId]
  
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
  # Arguments are specified inside an array, and may be interpreted as: 
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
  # @option callback rules [Object] applicable rules: an associated array with rule names id as key, and
  # as value an array containing for each concerned target:
  # - target [Object] the target
  # - params [Object] the awaited parameters specification
  # - category [String] the rule category
  resolve: (args..., callback) ->
    # end callback used to process executor results
    end = (data) ->
      return unless data?.method is 'resolve'
      executor.removeListener 'message', end
      return callback null, data.results[1] unless data.results[0]?
      # in case of error, wait for the executor to be respawned
      _.defer -> callback data.results[0]

    executor.on 'message', end
    # delegate to executor
    executor.send method: 'resolve', args:args
   
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
  #   @param targetId [ObjetId] the targeted item or event
  #
  # @param parameters [Array] array of awaited rule parameters
  # @param callback [Function] callback executed when rule was applied. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback result [Object] object send back by the executed rule
  execute: (args..., callback) ->
    # end callback used to process executor results
    end = (data) ->
      return unless data?.method is 'execute'
      executor.removeListener 'message', end
      return callback null, data.results[1] unless data.results[0]?
      # in case of error, wait for the executor to be respawned
      _.defer -> callback data.results[0]

    executor.on 'message', end
    # delegate to executor
    executor.send method: 'execute', args: args
     
  # Trigger a turn by executing turn rules
  #
  # @param callback [Function] Callback invoked at the end of the turn execution, with one parameter:
  # @option callback err [String] an error string. Null if no error occured.
  # @param _auto [Boolean] **private** used to distinguish manual and automatic turn execution
  triggerTurn: (callback, _auto = false) =>
    return #TODO for now
    logger.debug 'triggers turn rules...'
    notifier.notify 'turns', 'begin'
    sbxs = []

    # read all existing executables. @todo: use cached rules.
    Executable.find (err, executables) =>
      throw new Error "Cannot collect rules: #{err}" if err?

      rules = []
      # and for each of them, extract their turn rule.
      for executable in executables
        try
          # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
          # and singleton (like ModuleWatcher) will be broken.
          obj = require pathUtils.relative __dirname, executable.compiledPath
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
        # at the end, save and remove modified objects
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

        # use a sandbox to catch asynchronous errors
        sandbox = Domain.create()
        sandbox.name = rule.name
        sandbox.on 'error', (err) =>
          # exit at the first execution error (TODO do not dispose sandbox on Node 0.9.6)
          msg = "failed to select or execute rule #{rule.name}: #{err}"
          logger.warn msg
          notifier.notify 'turns', 'failure', rule.name, msg
          end()

        sandbox.bind(rule.select) (err, targets) =>
          # Do not emit an error, but stops this rule a first selection error.
          if err?
            sandbox.dispose()
            err = "failed to select rule #{rule.name}: #{err}"
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
            sandbox.bind(rule.execute) target, (err) =>
              # stop a first execution error.
              return executeEnd "failed to execute rule #{rule.name}: #{err}" if err?
              # store modified object for later
              saved.push obj for obj in rule.saved
              filterModified target, saved
              removed.push obj for obj in rule.removed
              executeEnd()
            
          # execute on each target and leave at the end.
          async.forEach targets, execute, (err) =>
            sandbox.dispose()
            if err?
              logger.warn err
              notifier.notify 'turns', 'failure', rule.name, err
              return end()
            # save all modified and removed object after the rule has executed
            updateDb rule, saved, removed, end

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