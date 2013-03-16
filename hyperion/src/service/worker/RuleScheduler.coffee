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
utils = require '../../util/common'
modelUtils = require '../../util/model'
TurnRule = require '../../model/TurnRule'
Executable = require '../../model/Executable'
notifier = require('../Notifier').get()
logger = require('../../logger').getLogger 'service'

frequency = process.env.frequency

# Compute the remaining time in milliseconds before the next turn execution
#
# @return number of milliseconds before the next turn.
nextTurn= () ->
  now = new Date()
  (frequency-now.getSeconds()%frequency)*1000-(now.getMilliseconds())

inProgress = false
commitSuicide = false
# avoid quitting on failures.
process.removeAllListeners 'uncaughtException'

# Trigger a turn by executing turn rules
#
# @param callback [Function] Callback invoked at the end of the turn execution, with one parameter:
# @option callback err [String] an error string. Null if no error occured.
# @param _auto [Boolean] **private** used to distinguish manual and automatic turn execution
trigger = (callback, _auto = false) ->
  return callback if inProgress
  inProgress = true
  logger.debug 'triggers turn rules...'
  notifier.notify 'turns', 'begin'

  turnEnd = -> 
    logger.debug 'end of turn'
    notifier.notify 'turns', 'end'
    # trigger the next turn
    if _auto and !commitSuicide
      _.delay ->
        trigger callback, true
      , nextTurn()
    # return callback
    inProgress = false
    callback null
    # commit suicide if an error was recovered
    process.exit 0 if commitSuicide

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
        if obj? and utils.isA(obj, TurnRule)
          rules.push obj 
          obj.id = executable.id
          obj.rank = 0 unless 'number' is utils.type obj.rank
      catch err
        # report require errors
        err = "failed to require executable #{executable.id}: #{err}"
        logger.warn err
        notifier.notify 'turns', 'error', executable.id, err

    # sort rules by rank
    rules.sort (a, b) -> a.rank - b.rank

    # function that updates dbs with rule's modifications
    updateDb = (rule, saved, removed, end) =>
      # at the end, save and remove modified objects
      removeModel = (target, removeEnd) =>
        logger.debug "remove model #{target.id}"
        target.remove (err) =>
          # stop a first execution error.
          removeEnd if err? then "Failed to remove model #{target.id} at the end of the turn: #{err}" else undefined
      # first removals
      async.forEach removed, removeModel, => 
        saveModel = (target, saveEnd) =>
          logger.debug "save model #{target.id}"
          target.save (err) =>
            # stop a first execution error.
            saveEnd if err? then "Failed to save model #{target.id} at the end of the turn: #{err}" else undefined
        # then saves
        async.forEach saved, saveModel, (err) =>
          if err?
            logger.warn err
            notifier.notify 'turns', 'failure', rule.id, err
            return end()
          notifier.notify 'turns', 'success', rule.id
          end()

    # function that select target of a rule and execute it on them
    selectAndExecute = (rule, end) =>
      # ignore disabled rules
      return end() unless rule.active
      notifier.notify 'turns', 'rule', rule.id

      # catch asynchronous errors and perform reporting before leaving
      error = (err) =>
        process.removeListener 'uncaughtException', error
        # exit at the first execution error
        msg = "failed to select or execute rule #{rule.id}: #{err}"
        logger.warn msg
        notifier.notify 'turns', 'failure', rule.id, msg
        commitSuicide = true
        turnEnd()

      process.on 'uncaughtException', error

      rule.select (err, targets) =>
        # Do not emit an error, but stops this rule a first selection error.
        if err?
          err = "failed to select rule #{rule.id}: #{err}"
          logger.warn err
          notifier.notify 'turns', 'failure', rule.id, err
          process.removeListener 'uncaughtException', error
          return end()

        unless Array.isArray(targets)
          process.removeListener 'uncaughtException', error
          return end() 

        logger.debug "rule #{rule.id} selected #{targets.length} target(s)"
        # arrays of modified objects
        saved = []
        removed = []

        # function that execute the current rule on a target
        execute = (target, executeEnd) =>
          rule.execute target, (err) =>
            # stop a first execution error.
            return executeEnd "failed to execute rule #{rule.id}: #{err}" if err?
            # store modified object for later
            saved.push obj for obj in rule.saved
            modelUtils.filterModified target, saved
            removed.push obj for obj in rule.removed
            executeEnd()
          
        # execute on each target and leave at the end.
        async.forEach targets, execute, (err) =>
          process.removeListener 'uncaughtException', error
          if err?
            logger.warn err
            notifier.notify 'turns', 'failure', rule.id, err
            return end()
          # save all modified and removed object after the rule has executed
          updateDb rule, saved, removed, end

    # select and execute each turn rule, NOT in parallel !
    async.forEachSeries rules, selectAndExecute, turnEnd

# For tests, do not use the automatic triggering
unless process.env.NODE_ENV is 'test'
  # Trigger automatic
  process.on 'rulesInitialized', -> trigger (->), true 

module.exports = 

  trigger: trigger