
/*
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
 */
'use strict';
var Executable, TurnRule, async, commitSuicide, frequency, inProgress, logger, modelUtils, nextTurn, notifier, pathUtils, trigger, utils, _;

_ = require('underscore');

async = require('async');

pathUtils = require('path');

utils = require('../../util/common');

modelUtils = require('../../util/model');

TurnRule = require('../../model/TurnRule');

Executable = require('../../model/Executable');

notifier = require('../Notifier').get();

logger = require('../../util/logger').getLogger('scheduler');

frequency = process.env.frequency;

nextTurn = function() {
  var now;
  now = new Date();
  return (frequency - now.getSeconds() % frequency) * 1000 - (now.getMilliseconds());
};

inProgress = false;

commitSuicide = false;

process.removeAllListeners('uncaughtException');

trigger = function(callback, _auto) {
  var turnEnd;
  if (_auto == null) {
    _auto = false;
  }
  if (inProgress) {
    return callback;
  }
  inProgress = true;
  logger.debug('triggers turn rules...');
  notifier.notify('turns', 'begin');
  turnEnd = function() {
    logger.debug('end of turn');
    notifier.notify('turns', 'end');
    if (_auto && !commitSuicide) {
      _.delay(function() {
        return trigger(callback, true);
      }, nextTurn());
    }
    inProgress = false;
    callback(null);
    if (commitSuicide) {
      return process.exit(0);
    }
  };
  return Executable.find((function(_this) {
    return function(err, executables) {
      var executable, obj, rules, selectAndExecute, updateDb, _i, _len;
      if (err != null) {
        throw new Error("Cannot collect rules: " + err);
      }
      rules = [];
      for (_i = 0, _len = executables.length; _i < _len; _i++) {
        executable = executables[_i];
        try {
          obj = require(pathUtils.relative(__dirname, executable.compiledPath));
          if ((obj != null) && utils.isA(obj, TurnRule)) {
            rules.push(obj);
            obj.id = executable.id;
            if ('number' !== utils.type(obj.rank)) {
              obj.rank = 0;
            }
          }
        } catch (_error) {
          err = _error;
          err = "failed to require executable " + executable.id + ": " + err;
          logger.warn(err);
          notifier.notify('turns', 'error', executable.id, err);
        }
      }
      rules.sort(function(a, b) {
        return a.rank - b.rank;
      });
      updateDb = function(rule, saved, removed, end) {
        var removeModel;
        modelUtils.purgeDuplicates(removed);
        modelUtils.purgeDuplicates(saved);
        removeModel = function(target, removeEnd) {
          logger.debug("remove model " + target.id);
          return target.remove(function(err) {
            return removeEnd(err != null ? "Failed to remove model " + target.id + " at the end of the turn: " + err : void 0);
          });
        };
        return async.forEach(removed, removeModel, function() {
          var saveModel;
          saveModel = function(target, saveEnd) {
            if (_.any(removed, function(obj) {
              return obj != null ? typeof obj.equals === "function" ? obj.equals(target) : void 0 : void 0;
            })) {
              return saveEnd();
            }
            logger.debug("save " + target._className + " " + target.id);
            return target.save(function(err) {
              return saveEnd(err != null ? "Failed to save model " + target.id + " at the end of the turn: " + err : void 0);
            });
          };
          return async.forEach(saved, saveModel, function(err) {
            if (err != null) {
              logger.warn(err);
              notifier.notify('turns', 'failure', rule.id, err);
              return end();
            }
            notifier.notify('turns', 'success', rule.id);
            return end();
          });
        });
      };
      selectAndExecute = function(rule, end) {
        var error;
        if (!rule.active) {
          return end();
        }
        notifier.notify('turns', 'rule', rule.id);
        error = function(err) {
          var msg;
          process.removeListener('uncaughtException', error);
          msg = "failed to select or execute rule " + rule.id + ": " + err;
          logger.warn(msg);
          notifier.notify('turns', 'failure', rule.id, msg);
          commitSuicide = true;
          return turnEnd();
        };
        process.on('uncaughtException', error);
        return rule.select(function(err, targets) {
          var execute, removed, saved;
          if (err != null) {
            err = "failed to select rule " + rule.id + ": " + err;
            logger.warn(err);
            notifier.notify('turns', 'failure', rule.id, err);
            process.removeListener('uncaughtException', error);
            return end();
          }
          if (!Array.isArray(targets)) {
            process.removeListener('uncaughtException', error);
            notifier.notify('turns', 'success', rule.id);
            return end();
          }
          logger.debug("rule " + rule.id + " selected " + targets.length + " target(s)");
          saved = [];
          removed = [];
          execute = function(target, executeEnd) {
            return rule.execute(target, function(err) {
              var _j, _k, _len1, _len2, _ref, _ref1;
              if (err != null) {
                return executeEnd("failed to execute rule " + rule.id + ": " + err);
              }
              _ref = rule.saved;
              for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
                obj = _ref[_j];
                saved.push(obj);
              }
              modelUtils.filterModified(target, saved);
              _ref1 = rule.removed;
              for (_k = 0, _len2 = _ref1.length; _k < _len2; _k++) {
                obj = _ref1[_k];
                removed.push(obj);
              }
              return executeEnd();
            });
          };
          return async.forEach(targets, execute, function(err) {
            process.removeListener('uncaughtException', error);
            if (err != null) {
              logger.warn(err);
              notifier.notify('turns', 'failure', rule.id, err);
              return end();
            }
            return updateDb(rule, saved, removed, end);
          });
        });
      };
      return async.forEachSeries(rules, selectAndExecute, turnEnd);
    };
  })(this));
};

if (process.env.NODE_ENV !== 'test') {
  process.on('rulesInitialized', function() {
    return trigger((function() {}), true);
  });
}

module.exports = {
  trigger: trigger
};
