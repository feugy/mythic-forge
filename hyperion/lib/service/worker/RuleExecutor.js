
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
var Event, Executable, Field, Item, Map, Player, Rule, async, internalResolve, logger, modelUtils, pathUtils, utils, _,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
  __slice = [].slice;

_ = require('underscore');

async = require('async');

pathUtils = require('path');

Rule = require('../../model/Rule');

Executable = require('../../model/Executable');

Item = require('../../model/Item');

Event = require('../../model/Event');

Field = require('../../model/Field');

Player = require('../../model/Player');

Map = require('../../model/Map');

utils = require('../../util/common');

modelUtils = require('../../util/model');

logger = require('../../util/logger').getLogger('executor');

internalResolve = function(actor, targets, wholeRule, worker, restriction, current, callback) {
  var remainingTargets, results;
  results = {};
  remainingTargets = 0;
  return Executable.find(function(err, executables) {
    var executable, obj, process, rules, _i, _len, _ref;
    if (err != null) {
      throw new Error("Cannot collect rules: " + err);
    }
    rules = [];
    for (_i = 0, _len = executables.length; _i < _len; _i++) {
      executable = executables[_i];
      try {
        obj = require(pathUtils.relative(__dirname, executable.compiledPath));
        if (obj != null) {
          obj.id = executable.id;
        }
        if ('string' !== utils.type(obj != null ? obj.category : void 0)) {
          if (obj != null) {
            obj.category = '';
          }
        }
        if ((obj != null) && utils.isA(obj, Rule) && obj.active) {
          if (_.isArray(restriction)) {
            if (_ref = obj.category, __indexOf.call(restriction, _ref) >= 0) {
              rules.push(obj);
            }
          } else if (_.isString(restriction)) {
            if (obj.id === restriction) {
              rules.push(obj);
            }
          } else {
            rules.push(obj);
          }
        }
      } catch (_error) {
        err = _error;
        err = "failed to require executable " + executable.id + ": " + err;
        logger.warn(err);
        return callback(err);
      }
    }
    logger.debug("" + rules.length + " candidate rules");
    if (!(targets.length > 0)) {
      return callback(null, results);
    }
    process = function(err) {
      if (err != null) {
        return callback("Cannot resolve rule because actor's (" + actor.id + ") linked item/event cannot be resolve: " + err);
      }
      return async.map(targets, function(target, next) {
        if (target instanceof Item || target instanceof Event) {
          return target.fetch(next);
        } else {
          return next(null, target);
        }
      }, function(err, targets) {
        if (err != null) {
          return callback("Cannot resolve rule because target's linked item/event cannot be resolve: " + err);
        }
        return async.each(targets, function(target, nextTarget) {
          return async.each(rules, function(rule, nextRule) {
            worker._errMsg = "Failed to resolve rule " + rule.id + ". Received exception ";
            return rule.canExecute(actor, target, {
              player: current
            }, function(err, parameters) {
              var result;
              if (err != null) {
                return nextRule("Failed to resolve rule " + rule.id + ". Received exception " + err);
              }
              if (Array.isArray(parameters)) {
                logger.debug("rule " + rule.id + " applies");
                if (wholeRule) {
                  result = {
                    rule: rule
                  };
                } else {
                  result = {
                    category: rule.category
                  };
                }
                result.target = target;
                result.params = parameters;
                if (!(rule.id in results)) {
                  results[rule.id] = [];
                }
                results[rule.id].push(result);
              }
              return nextRule();
            });
          }, nextTarget);
        }, function(err) {
          return callback(err, results);
        });
      });
    };
    if (actor instanceof Item) {
      return actor.fetch(process);
    } else {
      return process(null);
    }
  });
};

module.exports = {
  resolve: (function(_this) {
    return function() {
      var args, callback, email, restriction, _i;
      args = 4 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 3) : (_i = 0, []), restriction = arguments[_i++], email = arguments[_i++], callback = arguments[_i++];
      return Player.findOne({
        email: email
      }, function(err, current) {
        var actorId, playerId, targetId, x, y;
        if (err != null) {
          return callback("Cannot resolve rules. Failed to retrieve current player (" + email + "): " + err);
        }
        if (current == null) {
          return callback("No player with email " + email);
        }
        if (args.length === 1) {
          playerId = args[0];
          return Player.findOne({
            _id: playerId
          }, function(err, player) {
            if (err != null) {
              return callback("Cannot resolve rules. Failed to retrieve player (" + playerId + "): " + err);
            }
            if (player == null) {
              return callback("No player with id " + playerId);
            }
            logger.debug("resolve rules for player " + playerId);
            return internalResolve(player, [player], false, _this, restriction, current, callback);
          });
        } else if (args.length === 2) {
          actorId = args[0];
          targetId = args[1];
          return Item.find({
            $or: [
              {
                _id: actorId
              }, {
                _id: targetId
              }
            ]
          }, function(err, results) {
            var actor, findTarget, process, result, target, _j, _k, _len, _len1;
            if (err != null) {
              return resolveEnd("Cannot resolve rules. Failed to retrieve actor (" + actorId + ") or target (" + targetId + "): " + err);
            }
            for (_j = 0, _len = results.length; _j < _len; _j++) {
              result = results[_j];
              if (result.id === actorId) {
                actor = result;
              }
            }
            for (_k = 0, _len1 = results.length; _k < _len1; _k++) {
              result = results[_k];
              if (result.id === targetId) {
                target = result;
              }
            }
            process = function() {
              logger.debug("resolve rules for actor " + actorId + " and " + targetId);
              return internalResolve(actor, [target], false, _this, restriction, current, callback);
            };
            findTarget = function() {
              if (target != null) {
                return process();
              }
              return Event.findOne({
                _id: targetId
              }, function(err, result) {
                if (err != null) {
                  return callback("Cannot resolve rule. Failed to retrieve event target (" + targetId + "): " + err);
                }
                target = result;
                if (target != null) {
                  return process();
                }
                return Field.findOne({
                  _id: targetId
                }, function(err, result) {
                  if (err != null) {
                    return callback("Cannot resolve rule. Failed to retrieve field target (" + targetId + "): " + err);
                  }
                  if (result == null) {
                    return callback("No target with id " + targetId);
                  }
                  target = result;
                  return process();
                });
              });
            };
            if (actor != null) {
              return findTarget();
            }
            return Player.findOne({
              _id: actorId
            }, function(err, result) {
              if (err != null) {
                return resolveEnd("Cannot resolve rules. Failed to retrieve actor (" + actorId + "): " + err);
              }
              if (result == null) {
                return callback("No actor with id " + actorId);
              }
              actor = result;
              return findTarget();
            });
          });
        } else if (args.length === 3) {
          actorId = args[0];
          x = args[1];
          y = args[2];
          return Item.find({
            $or: [
              {
                _id: actorId
              }, {
                x: x,
                y: y
              }
            ]
          }, function(err, results) {
            var actor, i, result, _j, _len;
            if (err != null) {
              return callback("Cannot resolve rules. Failed to retrieve actor (" + actorId + ") or items at position x:" + x + " y:" + y + ": " + err);
            }
            actor = null;
            for (i = _j = 0, _len = results.length; _j < _len; i = ++_j) {
              result = results[i];
              if (result.id === actorId) {
                actor = result;
                if (!(actor.x === x && actor.y === y)) {
                  results.splice(i, 1);
                }
                break;
              }
            }
            if (actor == null) {
              return callback("No actor with id " + actorId);
            }
            if (actor.map == null) {
              return callback("Cannot resolve rules for actor " + actorId + " on map if it does not have a map !");
            }
            results = _.filter(results, function(item) {
              return actor.map.equals(item != null ? item.map : void 0);
            });
            return Field.findOne({
              mapId: actor.map.id,
              x: x,
              y: y
            }, function(err, field) {
              if (err != null) {
                return callback("Cannot resolve rules. Failed to retrieve field at position x:" + x + " y:" + y + ": " + err);
              }
              if (field != null) {
                results.splice(0, 0, field);
              }
              logger.debug("resolve rules for actor " + actorId + " at x:" + x + " y:" + y);
              return internalResolve(actor, results, false, _this, restriction, current, callback);
            });
          });
        } else {
          return callback("resolve() must be call with player id or actor and target ids, or actor id and coordinates");
        }
      });
    };
  })(this),
  execute: (function(_this) {
    return function() {
      var args, callback, email, parameters, ruleId, _i;
      ruleId = arguments[0], args = 5 <= arguments.length ? __slice.call(arguments, 1, _i = arguments.length - 3) : (_i = 1, []), parameters = arguments[_i++], email = arguments[_i++], callback = arguments[_i++];
      return Player.findOne({
        email: email
      }, function(err, current) {
        var actor, actorId, playerId, process, target, targetId;
        if (err != null) {
          return callback("Failed to execute rule " + rule.id + ". Failed to retrieve current player (" + email + "): " + err);
        }
        if (current == null) {
          return callback("No player with email " + email);
        }
        actor = null;
        target = null;
        process = function() {
          logger.debug("execute rule " + ruleId + " of " + actor.id + " for " + target.id);
          return internalResolve(actor, [target], true, _this, ruleId, current, function(err, rules) {
            var applicable, rule;
            if (err != null) {
              return callback("Cannot resolve rule " + ruleId + ": " + err);
            }
            applicable = null;
            applicable = _.find(rules[ruleId], function(obj) {
              if (ruleId in rules) {
                return target.equals(obj.target);
              }
            });
            if (applicable == null) {
              return callback("The rule " + ruleId + " of " + actor.id + " does not apply any more for " + target.id);
            }
            rule = applicable.rule;
            rule.saved = [];
            rule.removed = [];
            return modelUtils.checkParameters(parameters, applicable.params, actor, target, function(err) {
              if (err != null) {
                return callback("Invalid parameter for " + rule.id + ": " + err);
              }
              _this._errMsg = "Failed to execute rule " + rule.id + " of " + actor.id + " for " + target.id + ":";
              return rule.execute(actor, target, parameters, {
                player: current
              }, function(err, result) {
                var id, ids, saved;
                if (err != null) {
                  return callback("Failed to execute rule " + rule.id + " of " + actor.id + " for " + target.id + ": " + err);
                }
                saved = [];
                ids = (function() {
                  var _j, _len, _ref, _results;
                  _ref = rule.removed;
                  _results = [];
                  for (_j = 0, _len = _ref.length; _j < _len; _j++) {
                    id = _ref[_j];
                    if (_.isString(id)) {
                      _results.push(id);
                    }
                  }
                  return _results;
                })();
                return async.eachSeries([Item, Event, Player, Field, Map], function(Class, next) {
                  var enrich;
                  if (ids.length === 0) {
                    return next();
                  }
                  enrich = function(err, results) {
                    var i, removed, _j, _k, _len, _len1, _ref;
                    if (err != null) {
                      return next("Failed to execute rule " + rule.id + " of " + actor.id + " for " + target.id + ": " + err);
                    }
                    for (_j = 0, _len = results.length; _j < _len; _j++) {
                      removed = results[_j];
                      _ref = rule.removed;
                      for (i = _k = 0, _len1 = _ref.length; _k < _len1; i = ++_k) {
                        id = _ref[i];
                        if (!(id === removed.id)) {
                          continue;
                        }
                        rule.removed[i] = removed;
                        ids = _.without(ids, id);
                        break;
                      }
                    }
                    return next();
                  };
                  if ('findCached' in Class) {
                    return Class.findCached(ids, enrich);
                  } else {
                    return Class.find({
                      _id: {
                        $in: ids
                      }
                    }, enrich);
                  }
                }, function(err) {
                  if (err != null) {
                    return callback(err);
                  }
                  modelUtils.purgeDuplicates(rule.removed);
                  return async.each(rule.removed, function(obj, end) {
                    logger.debug("remove " + obj._className + " " + obj.id);
                    return obj.remove(function(err) {
                      return end(err);
                    });
                  }, function(err) {
                    if (err != null) {
                      return callback("Failed to execute rule " + rule.id + " of " + actor.id + " for " + target.id + ": " + err);
                    }
                    saved = [].concat(rule.saved);
                    modelUtils.filterModified(actor, saved);
                    modelUtils.filterModified(target, saved);
                    modelUtils.purgeDuplicates(saved);
                    return async.forEach(saved, function(obj, end) {
                      if (_.any(rule.removed, function(removed) {
                        return removed != null ? typeof removed.equals === "function" ? removed.equals(obj) : void 0 : void 0;
                      })) {
                        return end();
                      }
                      logger.debug("save modified " + obj._className + " " + obj.id + ", " + (obj.modifiedPaths().join(',')));
                      return obj.save(end);
                    }, function(err) {
                      if (err != null) {
                        return callback("Failed to execute rule " + rule.id + " of " + actor.id + " for " + target.id + ": " + err);
                      }
                      return callback(null, result);
                    });
                  });
                });
              });
            });
          });
        };
        if (args.length === 1) {
          playerId = args[0];
          if (playerId == null) {
            return callback("Player id is null !");
          }
          return Player.findOne({
            _id: playerId
          }, function(err, player) {
            if (err != null) {
              return callback("Cannot execute rule. Failed to retrieve player (" + playerId + "): " + err);
            }
            if (player == null) {
              return callback("No player with id " + playerId);
            }
            actor = player;
            target = player;
            return process();
          });
        } else if (args.length === 2) {
          actorId = args[0];
          targetId = args[1];
          if (targetId == null) {
            return callback("Target id is null !");
          }
          if (actorId == null) {
            return callback("Actor id is null !");
          }
          return Item.find({
            _id: {
              $in: [actorId, targetId]
            }
          }, function(err, results) {
            var findTarget, result, _j, _k, _len, _len1;
            if (err != null) {
              return callback("Cannot execute rule. Failed to retrieve actor (" + actorId + ") or target (" + targetId + "): " + err);
            }
            for (_j = 0, _len = results.length; _j < _len; _j++) {
              result = results[_j];
              if (result.id === actorId) {
                actor = result;
              }
            }
            for (_k = 0, _len1 = results.length; _k < _len1; _k++) {
              result = results[_k];
              if (result.id === targetId) {
                target = result;
              }
            }
            findTarget = function() {
              if (target != null) {
                return process();
              }
              return Event.findOne({
                _id: targetId
              }, function(err, result) {
                if (err != null) {
                  return callback("Cannot execute rule. Failed to retrieve event target (" + targetId + "): " + err);
                }
                target = result;
                if (target != null) {
                  return process();
                }
                return Field.findOne({
                  _id: targetId
                }, function(err, result) {
                  if (err != null) {
                    return callback("Cannot execute rule. Failed to retrieve field target (" + targetId + "): " + err);
                  }
                  if (result == null) {
                    return callback("No target with id " + targetId);
                  }
                  target = result;
                  return process();
                });
              });
            };
            if (actor != null) {
              return findTarget();
            }
            return Player.findOne({
              _id: actorId
            }, function(err, result) {
              if (err != null) {
                return callback("Cannot execute rules. Failed to retrieve actor (" + actorId + "): " + err);
              }
              if (result == null) {
                return callback("No actor with id " + actorId);
              }
              actor = result;
              return findTarget();
            });
          });
        } else {
          return callback('execute() must be call with player id or actor and target ids');
        }
      });
    };
  })(this)
};
