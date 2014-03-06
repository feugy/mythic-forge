
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
var Executable, LoggerFactory, Rule, RuleService, async, cluster, compiledRoot, depReg, fs, logger, loggerWorker, modelWatcher, notifier, pathToHyperion, pathToNodeModules, pathUtils, pool, ruleUtils, spawn, utils, _, _RuleService,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __slice = [].slice;

_ = require('underscore');

async = require('async');

cluster = require('cluster');

pathUtils = require('path');

fs = require('fs');

utils = require('../util/common');

Rule = require('../model/Rule');

ruleUtils = require('../util/rule');

Executable = require('../model/Executable');

notifier = require('../service/Notifier').get();

modelWatcher = require('../model/ModelWatcher').get();

LoggerFactory = require('../util/logger');

logger = LoggerFactory.getLogger('service');

loggerWorker = LoggerFactory.getLogger('worker');

depReg = /(.*)\s=\srequire\((.*)\);\n/;

compiledRoot = pathUtils.resolve(pathUtils.normalize(utils.confKey('game.executable.target')));

pathToHyperion = utils.relativePath(compiledRoot, pathUtils.join(__dirname, '..').replace('src', 'lib')).replace(/\\/g, '/');

pathToNodeModules = utils.relativePath(compiledRoot, ("" + (pathUtils.join(__dirname, '..', '..', '..', 'node_modules')) + "/").replace('src', 'lib')).replace(/\\/g, '/');

pool = [];

spawn = function(poolIdx, options) {
  var worker;
  worker = cluster.fork(options);
  pool[poolIdx] = worker;
  worker.on('exit', function(code, signal) {
    if (worker.suicide) {
      return;
    }
    spawn(poolIdx, options);
    return loggerWorker.info("respawn worker " + options.module + " with pid " + pool[poolIdx].process.pid);
  });
  return worker.on('message', function(data) {
    if ((data != null ? data.event : void 0) === 'change') {
      return modelWatcher.emit.apply(modelWatcher, ['change'].concat(data.args));
    } else if ((data != null ? data.event : void 0) === notifier.NOTIFICATION) {
      return notifier.notify.apply(notifier, data.args);
    } else if ((data != null ? data.event : void 0) === 'log') {
      return LoggerFactory.emit('log', data.args);
    }
  });
};

_RuleService = (function() {
  function _RuleService() {
    this.triggerTurn = __bind(this.triggerTurn, this);
    this["export"] = __bind(this["export"], this);
    this.pauseTime = __bind(this.pauseTime, this);
    this.setTime = __bind(this.setTime, this);
    if (cluster.isMaster) {
      Executable.resetAll(true, function(err) {
        var options;
        if (err != null) {
          throw new Error("Failed to initialize RuleService: " + err);
        }
        cluster.setupMaster({
          exec: pathUtils.join(__dirname, '..', '..', 'lib', 'service', 'worker', 'Launcher')
        });
        options = {
          module: 'RuleExecutor'
        };
        spawn(0, options);
        loggerWorker.info("" + process.pid + " spawn worker " + options.module + " with pid " + pool[0].process.pid);
        options = {
          module: 'RuleScheduler',
          frequency: utils.confKey('turn.frequency')
        };
        spawn(1, options);
        loggerWorker.info("" + process.pid + " spawn worker " + options.module + " with pid " + pool[1].process.pid);
        return modelWatcher.on('change', function(operation, className, changes, wId) {
          var id, worker, _ref, _results;
          wId = wId != null ? wId : process.pid;
          _ref = cluster.workers;
          _results = [];
          for (id in _ref) {
            worker = _ref[id];
            if (worker.process.pid !== wId) {
              _results.push(worker.send({
                event: 'change',
                args: [operation, className, changes, wId]
              }));
            }
          }
          return _results;
        });
      });
      ruleUtils.timer.on('change', function(time) {
        return notifier.notify('time', 'change', time.valueOf());
      });
    }
  }

  _RuleService.prototype.setTime = function(time) {
    if (time == null) {
      time = null;
    }
    return ruleUtils.timer.set(time);
  };

  _RuleService.prototype.pauseTime = function(stopped) {
    return ruleUtils.timer.stopped = stopped === true;
  };

  _RuleService.prototype["export"] = function(callback) {
    return Executable.find((function(_this) {
      return function(err, executables) {
        var readContent, rules;
        if (err != null) {
          throw new Error("Cannot collect rules: " + err);
        }
        rules = {};
        readContent = function(executable, done) {
          return fs.readFile(executable.compiledPath, function(err, content) {
            var deps, end, expr, i, obj, start, vars, _i, _len, _ref;
            if (err != null) {
              return callback("Failed to export rules. Error while reading rule " + executable.compiledPath + ": " + err);
            }
            content = content.toString();
            if (-1 !== content.indexOf('model/Rule')) {
              content = content.replace('\n    this.execute = __bind(this.execute, this);\n', '\n');
              start = content.search(/^  .*\.prototype\.execute\s=\sfunction\(.*\)\s\{/im);
              end = content.indexOf('\n  };', start) - 1;
              content = content.slice(0, start) + content.slice(end + 6);
              try {
                obj = require(pathUtils.relative(__dirname, executable.compiledPath));
                if (!obj.active) {
                  return done();
                }
              } catch (_error) {
                err = _error;
                return done();
              }
            } else {
              while (true) {
                start = content.search(/^  _[^:]+: function/m);
                if (start === -1) {
                  break;
                }
                end = start;
                _ref = [/^  \},$/m, /^  \}$/m, /^\};$/m];
                for (i = _i = 0, _len = _ref.length; _i < _len; i = ++_i) {
                  expr = _ref[i];
                  end = content.slice(start).search(expr);
                  if (end !== -1) {
                    end += start + 4 - i;
                    break;
                  }
                }
                content = content.slice(0, start) + content.slice(end);
              }
            }
            deps = [];
            vars = [];
            while (-1 !== content.search(depReg)) {
              content = content.replace(depReg, function(str, variable, dep) {
                dep = dep.replace("'" + pathToHyperion, "'hyperion");
                dep = dep.replace("'" + pathToNodeModules, "'");
                deps.push(dep);
                vars.push(variable);
                return '';
              });
              content = content.replace(" " + vars[vars.length - 1] + ",", '');
            }
            content = content.replace('module.exports =', 'return');
            content = "define('" + executable.id + "', [" + (deps.join(',')) + "], function(" + (vars.join(',')) + "){\n" + content + "\n});";
            rules[executable.id] = content;
            return done();
          });
        };
        return async.forEach(executables, readContent, function(err) {
          return callback(err, rules);
        });
      };
    })(this));
  };

  _RuleService.prototype.resolve = function() {
    var args, callback, end, id, _i;
    args = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), callback = arguments[_i++];
    id = utils.generateToken(6);
    end = (function(_this) {
      return function(data) {
        if (!((data != null ? data.method : void 0) === 'resolve' && (data != null ? data.id : void 0) === id)) {
          return;
        }
        pool[0].removeListener('message', end);
        if (data.results[0] === 'worker not ready') {
          return _.delay(function() {
            return _this.resolve.apply(_this, args.concat(callback));
          }, 10);
        }
        if (data.results[0] == null) {
          return callback(null, data.results[1]);
        }
        return _.delay(function() {
          return callback(data.results[0]);
        }, 150);
      };
    })(this);
    pool[0].on('message', end);
    return pool[0].send({
      method: 'resolve',
      args: args,
      id: id
    });
  };

  _RuleService.prototype.execute = function() {
    var args, callback, end, id, _i;
    args = 2 <= arguments.length ? __slice.call(arguments, 0, _i = arguments.length - 1) : (_i = 0, []), callback = arguments[_i++];
    id = utils.generateToken(6);
    end = (function(_this) {
      return function(data) {
        if (!((data != null ? data.method : void 0) === 'execute' && (data != null ? data.id : void 0) === id)) {
          return;
        }
        pool[0].removeListener('message', end);
        if (data.results[0] === 'worker not ready') {
          return _.delay(function() {
            return _this.execute.apply(_this, args.concat(callback));
          }, 10);
        }
        if (data.results[0] == null) {
          return callback(null, data.results[1]);
        }
        return _.delay(function() {
          return callback(data.results[0]);
        }, 150);
      };
    })(this);
    pool[0].on('message', end);
    return pool[0].send({
      method: 'execute',
      args: args,
      id: id
    });
  };

  _RuleService.prototype.triggerTurn = function(callback) {
    var end, id;
    id = utils.generateToken(6);
    end = (function(_this) {
      return function(data) {
        if (!((data != null ? data.method : void 0) === 'trigger' && (data != null ? data.id : void 0) === id)) {
          return;
        }
        pool[1].removeListener('message', end);
        if (data.results[0] === 'worker not ready') {
          return _.delay(function() {
            return _this.triggerTurn.apply(_this, [callback]);
          }, 10);
        }
        if (data.results[0] == null) {
          return callback(null);
        }
        return _.delay(function() {
          return callback(data.results[0]);
        }, 150);
      };
    })(this);
    pool[1].on('message', end);
    return pool[1].send({
      method: 'trigger',
      id: id
    });
  };

  return _RuleService;

})();

RuleService = (function() {
  var _instance;

  function RuleService() {}

  _instance = void 0;

  RuleService.get = function() {
    return _instance != null ? _instance : _instance = new _RuleService();
  };

  return RuleService;

})();

module.exports = RuleService;
