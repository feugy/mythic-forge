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

_ = require 'lodash'
async = require 'async'
cluster = require 'cluster'
{resolve, normalize, join, relative} = require 'path'
fs = require 'fs'
{confKey, generateToken, relativePath, fromRule} = require '../util/common'
Rule = require '../model/Rule'
{timer} = require '../util/rule'
Executable = require '../model/Executable'
Map = require '../model/Map'
notifier = require('../service/Notifier').get()
modelWatcher = require('../model/ModelWatcher').get()
ContactService = require('../service/ContactService').get()
LoggerFactory = require '../util/logger'
logger = LoggerFactory.getLogger 'service'
loggerWorker = LoggerFactory.getLogger 'worker'

# Regular expression to extract dependencies from rules
depReg = /(.*)\s=\srequire\((.*)\);\n/
compiledRoot = resolve normalize confKey 'game.executable.target'
pathToHyperion = relativePath(compiledRoot, join(__dirname, '..').replace 'src', 'lib').replace /\\/g, '/' # for Sumblime text highligth bug /'
pathToNodeModules = relativePath(compiledRoot, "#{join __dirname, '..', '..', '..', 'node_modules'}/".replace 'src', 'lib').replace /\\/g, '/' # for Sumblime text highligth bug /'

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
  worker.setMaxListeners 0
  pool[poolIdx] = worker

  loggerWorker.info "#{process.pid} spawn worker #{options.module} with pid #{worker.process.pid}"

  # relaunch immediately dead worker
  worker.on 'exit', (code, signal) ->
    # evict model cache for main and other threads
    Map.cleanModelCache()
    for id, other of cluster.workers when other isnt worker
      try
        worker.send event: 'modelReset'
      catch err
        # silent error: if a worker is closed, it will be automatically restarted
    # respawn dead worker
    spawn poolIdx, options
    loggerWorker.info "respawn worker #{options.module} with pid #{pool[poolIdx].process.pid}"

  # relay important message from worker to master thread
  worker.on 'message', (data) ->
    if data?.event is 'change'
      # trigger the change as if it comes from the master modelWatcher
      modelWatcher.emit.apply modelWatcher, ['change'].concat data.args
    else if data?.event is notifier.NOTIFICATION
      # trigger the notification as if it comes from the master notifier
      notifier.notify.apply notifier, data.args
    else if data?.event is 'sendTo'
      # check data format
      unless data.msg? and data.players?
        logger.error "campaign must be an object with 'msg' and 'players' properties:", data
      # send campaign, and just log results
      ContactService.sendTo data.players, data.msg, (err, report) =>
        return logger.error "failed to send campaign: #{err}" if err?
        logger.info "send campaign", report
    else if data?.event is 'log'
      LoggerFactory.emit 'log', data.args

# The RuleService is somehow the rule engine: it indicates which rule are applicables at a given situation
# It also manage turn rules, and game timer.
#
# @Todo: refresh cache when executable changes...
class _RuleService

  constructor: ->
    # only on master thread
    return unless cluster.isMaster
    Executable.resetAll true, (err) ->
      throw new Error "Failed to initialize RuleService: #{err}" if err?
      cluster.setupMaster
        exec: join __dirname, '..', '..', 'lib', 'service', 'worker', 'Launcher'

      spawn 0, module: 'RuleExecutor'
      spawn 1,
        module: 'RuleScheduler'
        # frequency, in seconds.
        frequency: confKey 'turn.frequency'

    # when a change is detected in master, send it to workers
    modelWatcher.on 'change', (operation, className, changes, wId) ->
      # use master pid if it comes from the master
      wId = if wId? then wId else process.pid
      for id, worker of cluster.workers when worker.process.pid isnt wId
        try
          worker.send event: 'change', args:[operation, className, changes, wId]
        catch err
          # silent error: if a worker is closed, it will be automatically restarted

    # on version changes, we must reset worker's cache
    notifier.on notifier.NOTIFICATION, (kind, details) =>
      return unless details is 'VERSION_RESTORED'
      Executable.resetAll true, (err) ->
        # silent error
        for id, worker of cluster.workers when worker.process.pid isnt process.pid
          try
            worker.send event: 'executableReset'
          catch err
            # silent error: if a worker is closed, it will be automatically restarted

    # propagate time changes
    timer.on 'change', (time) ->
      notifier.notify 'time', 'change', time.valueOf()

  # Allow to change game timer
  #
  # @param time [Number] Unix epoch of new time. null to reset to current
  setTime: (time = null) =>
    return if fromRule()
    timer.set time

  # Allow to pause or resume game timer
  #
  # @param stopped [Boolean] true to pause time, false to resumt it
  pauseTime: (stopped) =>
    return if fromRule()
    timer.stopped = stopped is true

  # Exports existing rules to clients: turn rules are ignored and execute() function is not exposed.
  #
  # @param callback [Function] callback executed when rules where exported. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback rules [Object] exported rules, in text, indexed by rule ids.
  export: (callback) =>
    return if fromRule callback
    # read all existing executables. @todo: use cached rules.
    Executable.find (err, executables) =>
      throw new Error "Cannot collect rules: #{err}" if err?

      rules = {}
      readContent = (executable, done) =>
        fs.readFile executable.compiledPath, (err, content) =>
          return callback "Failed to export rules. Error while reading rule #{executable.compiledPath}: #{err}" if err?
          content = content.toString()

          # rules specific behaviour
          if -1 isnt content.indexOf 'model/Rule'
            # removes the executable part
            content = content.replace '\n    this.execute = bind(this.execute, this);\n', '\n'

            start = content.search /^  .*\.prototype\.execute\s=\sfunction\(.*\)\s\{/im
            end = content.indexOf('\n  };', start)-1

            content = content[0...start]+content[end+6..]
            try
              # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
              # and singleton (like ModuleWatcher) will be broken.
              obj = require relative __dirname, executable.compiledPath
              # inactive rule: do not export
              return done() unless obj.active
            catch err
              # failing rule: do not export
              return done()
          else
            # script privacy enforcement
            while true
              start = content.search /^  _[^:]+: function/m
              break if start is -1
              end = start
              for expr, i in [/^  \},$/m, /^  \}$/m, /^\};$/m]
                end = content[start..].search expr
                if end isnt -1
                  end += start+4-i
                  break
              content = content[0...start]+content[end..]

          # gets the required dependencies
          deps = []
          vars = []
          while -1 isnt content.search depReg
            # removes the require directive and extract relevant variable and path
            content = content.replace depReg, (str, variable, dep)->
              dep = dep.replace "'#{pathToHyperion}", "'hyperion"
              dep = dep.replace "'#{pathToNodeModules}", "'"
              deps.push dep
              vars.push variable
              return ''

            # removes also the scope declaration
            content = content.replace new RegExp(",? #{vars[vars.length-1]}"), ''

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
  # @option callback rules [Object] applicable rules: an associated array with rule names id as key, and
  # as value an array containing for each concerned target:
  # - target [Object] the target
  # - params [Object] the awaited parameters specification
  # - category [String] the rule category
  resolve: (args..., callback) ->
    return if fromRule callback
    # generate a random request Id
    id = generateToken 6
    # end callback used to process executor results
    end = (data) =>
      return unless data?.method is 'resolve' and data?.id is id
      pool[0].removeListener 'message', end
      # special case: worker not ready yet. Try later.
      if data.results[0] is 'worker not ready'
        return _.delay =>
          @resolve.apply @, args.concat callback
        , 10
      return callback null, data.results[1] unless data.results[0]?
      # in case of error, wait for the executor to be respawned
      _.delay ->
        callback data.results[0]
      , 150

    pool[0].on 'message', end
    # delegate to executor
    try
      pool[0].send method: 'resolve', args:args, id: id
    catch err
      pool[0].removeListener 'message', end
      callback "Executor process dead: #{err}"

  # Execute a particular rule for a given situation.
  # As a first validation, the rule is resolved for the target.
  # All objects modified by the rule will be registered in database.
  #
  # @param ruleId [String] the executed rule id
  #
  # @overload execute(ruleId, playerId, parameters, email, callback)
  #   Executes a specific rule for a player
  #   @param playerId [ObjectId] the concerned player's id
  #
  # @overload execute(ruleId, actorId, targetId, parameters, email, callback)
  #   Executes a specific rule for an actor and a given target
  #   @param actorId [ObjectId] the concerned item/player id
  #   @param targetId [ObjetId] the targeted item or event
  #
  # @param parameters [Array] array of awaited rule parameters
  # @param email [String] email of currently connected player
  # @param callback [Function] callback executed when rule was applied. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback result [Object] object send back by the executed rule
  execute: (args..., callback) ->
    return if fromRule callback
    # generate a random request Id
    id = generateToken 6
    # end callback used to process executor results
    end = (data) =>
      return unless data?.method is 'execute' and data?.id is id
      pool[0].removeListener 'message', end
      # special case: worker not ready yet. Try later.
      if data.results[0] is 'worker not ready'
        return _.delay =>
          @execute.apply @, args.concat callback
        , 10
      return callback null, data.results[1]  unless data.results[0]?
      # in case of error, wait for the executor to be respawned
      _.delay ->
        callback data.results[0]
      , 150

    pool[0].on 'message', end
    # delegate to executor
    try
      pool[0].send method: 'execute', args: args, id: id
    catch err
      pool[0].removeListener 'message', end
      callback "Executor process dead: #{err}"


  # Trigger a turn by executing turn rules
  #
  # @param callback [Function] Callback invoked at the end of the turn execution, with one parameter:
  # @option callback err [String] an error string. Null if no error occured.
  triggerTurn: (callback) =>
    return if fromRule callback
    # generate a random request Id
    id = generateToken 6
    # end callback used to process scheduler results
    end = (data) =>
      return unless data?.method is 'trigger' and data?.id is id
      pool[1].removeListener 'message', end
      # special case: worker not ready yet. Try later.
      if data.results[0] is 'worker not ready'
        return _.delay =>
          @triggerTurn.apply @, [callback]
        , 10
      return callback null unless data.results[0]?
      # in case of error, wait for the executor to be respawned
      _.delay ->
        callback data.results[0]
      , 150

    pool[1].on 'message', end
    # delegate to scheduler
    try
      pool[1].send method: 'trigger', id: id
    catch err
      pool[1].removeListener 'message', end
      callback "Scheduler process dead: #{err}"

class RuleService
  _instance = undefined
  @get: ->
    _instance ?= new _RuleService()

module.exports = RuleService