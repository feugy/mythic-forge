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
cluster = require 'cluster'
pathUtils = require 'path'
fs = require 'fs'
utils = require '../util/common'
Rule = require '../model/Rule'
ruleUtils = require '../util/rule'
Executable = require '../model/Executable'
notifier = require('../service/Notifier').get()
modelWatcher = require('../model/ModelWatcher').get()
logger = require('../logger').getLogger 'service'
  
# Regular expression to extract dependencies from rules
depReg = /(.*)\s=\srequire\((.*)\);\n/

# Pool of workers.
pool = []

# Spawn a worker with respawn facilities and changes propagations
# 
# @param poolIdx [Number] index under which the spawned worker is store
# @param options [Object] worker creation options. All of them are passed as environement variables to
# the spawned worker. Only one is mandatory:
# @option options module [String] path (relative to the launcher) of the spawned script
spawn = (poolIdx, options) ->
  worker = cluster.fork options
  pool[poolIdx] = worker

  # relaunch immediately dead worker
  worker.on 'exit', (code, signal) ->
    return if worker.suicide
    spawn poolIdx, options
    logger.info "respawn worker #{options.module} with pid #{pool[poolIdx].process.pid}"

  worker.on 'message', (data) ->
    if data?.event is 'change'
      # trigger the change as if it comes from the master modelWatcher
      modelWatcher.emit.apply modelWatcher, ['change'].concat data.args
    else if data?.event is notifier.NOTIFICATION
      # trigger the notification as if it comes from the master notifier
      notifier.notify.apply notifier, data.args

# The RuleService is somehow the rule engine: it indicates which rule are applicables at a given situation 
# It also manage turn rules, and game timer.
#
# @Todo: refresh cache when executable changes... 
class _RuleService

  constructor: ->
    if cluster.isMaster
      Executable.resetAll true, (err) ->
        throw new Error "Failed to initialize RuleService: #{err}" if err?
        cluster.setupMaster 
          exec: pathUtils.join __dirname, '..', '..', 'lib', 'service', 'worker', 'Launcher'

        options = 
          module: 'RuleExecutor'
        spawn 0, options
        logger.info "#{process.pid} spawn worker #{options.module} with pid #{pool[0].process.pid}"
        
        options = 
          module: 'RuleScheduler'
          # frequency, in seconds.
          frequency: utils.confKey 'turn.frequency'
        spawn 1, options
        logger.info "#{process.pid} spawn worker #{options.module} with pid #{pool[1].process.pid}"

        # when a change is detected in master, send it to workers
        modelWatcher.on 'change', (operation, className, changes, wId) ->
          # use master pid if it comes from the master
          wId = if wId? then wId else process.pid
          for id, worker of cluster.workers when worker.process.pid isnt wId
            worker.send event: 'change', args:[operation, className, changes, wId]

      # propagate time changes
      ruleUtils.timer.on 'change', (time) ->
        notifier.notify 'time', 'change', time.valueOf()
        
  # Allow to change game timer
  #
  # @param time [Number] Unix epoch of new time. null to reset to current
  setTime: (time = null) => ruleUtils.timer.set time

  # Allow to pause or resume game timer
  #
  # @param stopped [Boolean] true to pause time, false to resumt it
  pauseTime: (stopped) => ruleUtils.timer.stopped = stopped is true

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
          
          # rules specific behaviour
          if -1 isnt content.indexOf '})(Rule);'
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
          content = "define('#{executable.id}', [#{deps.join ','}], function(#{vars.join ','}){\n#{content}\n});"
          
          # and keep the remaining code
          rules[executable.id] = content 
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
    end = (data) =>
      return unless data?.method is 'resolve'
      pool[0].removeListener 'message', end
      # special case: worker not ready yet. Try later.
      if data.results[0] is 'worker not ready'
        return _.delay => 
          @resolve.apply @, args.concat callback
        , 10
      return callback null, data.results[1] unless data.results[0]?
      # in case of error, wait for the executor to be respawned
      _.defer -> callback data.results[0]

    pool[0].on 'message', end
    # delegate to executor
    pool[0].send method: 'resolve', args:args
   
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
  execute: (args..., callback) ->
    # end callback used to process executor results
    end = (data) =>
      return unless data?.method is 'execute'
      pool[0].removeListener 'message', end
      # special case: worker not ready yet. Try later.
      if data.results[0] is 'worker not ready'
        return _.delay => 
          @execute.apply @, args.concat callback
        , 10
      return callback null, data.results[1] unless data.results[0]?
      # in case of error, wait for the executor to be respawned
      _.defer -> callback data.results[0]

    pool[0].on 'message', end
    # delegate to executor
    pool[0].send method: 'execute', args: args
     
  # Trigger a turn by executing turn rules
  #
  # @param callback [Function] Callback invoked at the end of the turn execution, with one parameter:
  # @option callback err [String] an error string. Null if no error occured.
  triggerTurn: (callback) =>
    # end callback used to process scheduler results
    end = (data) =>
      return unless data?.method is 'trigger'
      pool[1].removeListener 'message', end
      # special case: worker not ready yet. Try later.
      if data.results[0] is 'worker not ready'
        return _.delay => 
          @triggerTurn.apply @, [callback]
        , 10
      return callback null unless data.results[0]?
      # in case of error, wait for the executor to be respawned
      _.defer -> callback data.results[0]

    pool[1].on 'message', end
    # delegate to scheduler
    pool[1].send method: 'trigger'

class RuleService
  _instance = undefined
  @get: ->
    _instance ?= new _RuleService()

module.exports = RuleService