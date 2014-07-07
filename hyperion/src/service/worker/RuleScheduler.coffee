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
{isA, type, fromRule} = require '../../util/common'
{processCampaigns} = require '../../util/rule'
utils = require '../../util/model'
TurnRule = require '../../model/TurnRule'
Executable = require '../../model/Executable'
notifier = require('../Notifier').get()
logger = require('../../util/logger').getLogger 'scheduler'

frequency = process.env.frequency

# Compute the remaining time in milliseconds before the next turn execution
#
# @return number of milliseconds before the next turn.
nextTurn= () ->
  now = new Date()
  (frequency-now.getSeconds()%frequency)*1000-(now.getMilliseconds())

inProgress = false
commitSuicide = false

# Trigger a turn by executing turn rules
#
# @param callback [Function] Callback invoked at the end of the turn execution, with one parameter:
# @option callback err [String] an error string. Null if no error occured.
# @param _auto [Boolean] **private** used to distinguish manual and automatic turn execution
trigger = (callback, _auto = false) ->
  return if fromRule callback
  return callback if inProgress

  # avoid quitting on failures.
  process.removeAllListeners 'uncaughtException'

  inProgress = true
  logger.debug 'triggers turn rules...'
  notifier.notify 'turns', 'begin'

  turnEnd = -> 
    logger.debug 'end of turn'
    notifier.notify 'turns', 'end'
    # trigger the next turn
    # disable if frequency isn't strictly positive
    if _auto and !commitSuicide and frequency > 0
      _.delay ->
        trigger callback, true
      , nextTurn()
    # return callback
    inProgress = false
    callback null
    # commit suicide if an error was recovered
    process.exit 0 if commitSuicide

  checkFailure = (rule, err, end) =>
    if err?
      logger.warn err
      notifier.notify 'turns', 'failure', rule.id, err.message or err
      end()
      return true
    false

  # read all existing executables. @todo: use cached rules.
  Executable.find (err, executables) =>
    throw new Error "Cannot collect rules: #{err}" if err?

    rules = []
    # and for each of them, extract their turn rule.
    for executable in executables
      try
        # CAUTION ! we need to use relative path. Otherwise, require inside rules will not use the module cache,
        # and singleton (like ModuleWatcher) will be broken.
        obj = require relative __dirname, executable.compiledPath
        if obj? and isA(obj, TurnRule)
          rules.push obj 
          obj.id = executable.id
          obj.rank = 0 unless 'number' is type obj.rank
      catch err
        # report require errors
        err = "failed to require executable #{executable.id}: #{err}"
        logger.warn err
        notifier.notify 'turns', 'error', executable.id, err

    # sort rules by rank
    rules.sort (a, b) -> a.rank - b.rank

    # function that updates dbs with rule's modifications
    updateDb = (rule, saved, removed, campaigns, end) =>
      # removes duplicates, and do not save removed instances
      utils.purgeDuplicates removed

      # first removals
      async.forEach removed, (obj, removeEnd) -> 
        logger.debug "remove #{obj._className} #{obj.id}"
        obj.remove removeEnd
      , (err) => 
        return if checkFailure rule, err, end

        # removes duplicates and sort to save new objects first
        utils.purgeDuplicates saved
        saved.sort (o1, o2) -> if o1.id? and not o2.id? then 1 else if o2.id? and not o1.id? then -1 else 0
        
        # then save
        async.forEach saved, (obj, saveEnd) -> 
          # do not re-save models that were already removed !
          return saveEnd() if _.any rule.removed, (removed) -> removed?.equals?(obj)
          logger.debug "save modified #{obj._className} #{obj.id}, #{obj.modifiedPaths().join(',')}"
          obj.save saveEnd
        , (err) =>
          return if checkFailure rule, err, end

          # everything was fine, now, send campaigns
          processCampaigns campaigns
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
        commitSuicide = true
        checkFailure rule, msg, turnEnd

      process.on 'uncaughtException', error

      rule.select (err, targets) =>
        # Do not emit an error, but stops this rule a first selection error.
        if err?
          err = "failed to select rule #{rule.id}: #{err}"
          process.removeListener 'uncaughtException', error
          return checkFailure rule, err, end

        unless Array.isArray(targets)
          process.removeListener 'uncaughtException', error
          notifier.notify 'turns', 'success', rule.id
          return end() 

        logger.debug "rule #{rule.id} selected #{targets.length} target(s)"
        # arrays of modified objects
        saved = []
        removed = []
        campaigns = []

        # execute on each target and leave at the end.
        async.forEach targets, (target, executeEnd) =>
          # reinitialize creation and removal arrays.
          rule.saved = []
          rule.removed = []
          # campaign handling
          rule.sendCampaign = (campaign) => campaigns.push campaign

          rule.execute target, (err) =>
            # stop a first execution error.
            return executeEnd "failed to execute rule #{rule.id}: #{err}" if err?
            # store modified object for later
            utils.filterModified obj, saved for obj in [target].concat rule.saved
            removed = removed.concat rule.removed
            executeEnd()
        , (err) =>
          rule.sendCampaign = () ->
          process.removeListener 'uncaughtException', error
          return if checkFailure rule, err, end
          # save all modified and removed object after the rule has executed
          updateDb rule, saved, removed, campaigns, end

    # select and execute each turn rule, NOT in parallel !
    async.forEachSeries rules, selectAndExecute, turnEnd

# For tests, do not use the automatic triggering
unless process.env.NODE_ENV is 'test'
  # Trigger automatic
  process.on 'rulesInitialized', -> trigger (->), true 

module.exports = 

  trigger: trigger