
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
var Executable, Item, Rule, TurnRule, async, cleanNodeCache, cluster, coffee, compileFile, compiledRoot, encoding, executables, fs, hintOpts, jshint, logger, modelUtils, modelWatcher, path, pathToHyperion, pathToNodeModules, pathUtils, requireExecutable, requirePrefix, root, search, supported, utils, wasNew, _,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; },
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

_ = require('underscore');

fs = require('fs-extra');

path = require('path');

async = require('async');

coffee = require('coffee-script');

cluster = require('cluster');

pathUtils = require('path');

jshint = require('jshint').JSHINT;

modelWatcher = require('./ModelWatcher').get();

logger = require('../util/logger').getLogger('model');

utils = require('../util/common');

modelUtils = require('../util/model');

Rule = require('../model/Rule');

TurnRule = require('../model/TurnRule');

hintOpts = {
  asi: true,
  boss: true,
  debug: false,
  eqnull: true,
  evil: true,
  iterator: true,
  laxcomma: true,
  loopfunc: true,
  multistr: true,
  notypeof: true,
  proto: true,
  smarttabs: true,
  shadow: true,
  sub: true,
  supernew: true,
  validthis: true,
  node: true
};

Item = null;

root = path.resolve(path.normalize(utils.confKey('game.executable.source')));

compiledRoot = path.resolve(path.normalize(utils.confKey('game.executable.target')));

encoding = utils.confKey('game.executable.encoding', 'utf8');

supported = ['.coffee', '.js'];

requirePrefix = 'hyperion';

pathToHyperion = utils.relativePath(compiledRoot, path.join(__dirname, '..').replace('src', 'lib')).replace(/\\/g, '/');

pathToNodeModules = utils.relativePath(compiledRoot, path.join(__dirname, '..', '..', '..', 'node_modules').replace('src', 'lib')).replace(/\\/g, '/');

modelWatcher.on('change', function(operation, className, changes, wId) {
  var attr, value;
  if (!((wId != null) && className === 'Executable')) {
    return;
  }
  switch (operation) {
    case 'creation':
      return executables[changes.id] = changes;
    case 'update':
      if (!(changes.id in executables)) {
        return;
      }
      for (attr in changes) {
        value = changes[attr];
        if (!(attr === 'id')) {
          executables[changes.id][attr] = value;
        }
      }
      return cleanNodeCache();
    case 'deletion':
      if (!(changes.id in executables)) {
        return;
      }
      cleanNodeCache();
      return delete executables[changes.id];
  }
});

wasNew = {};

cleanNodeCache = function() {
  var executable, id, _results;
  _results = [];
  for (id in executables) {
    executable = executables[id];
    _results.push(delete require.cache[path.resolve(path.normalize(executable.compiledPath))]);
  }
  return _results;
};

compileFile = function(executable, callback) {
  var content, exc;
  content = executable.content.replace(new RegExp("(require\\s*\\(?\\s*[\"'])" + requirePrefix, 'g'), "$1" + pathToHyperion);
  content = content.replace(new RegExp("(require\\s*\\(?\\s*[\"'])(?!\\.)", 'g'), "$1" + pathToNodeModules + "/");
  try {
    switch (executable.lang) {
      case 'coffee':
        content = coffee.compile(content, {
          bare: true
        });
        break;
      case 'js':
        if (!jshint(content, hintOpts)) {
          throw "" + jshint.errors[0].line + ":" + jshint.errors[0].character + ", " + jshint.errors[0].reason;
        }
    }
  } catch (_error) {
    exc = _error;
    return callback("Error while compilling executable " + executable.id + ": " + exc);
  }
  return fs.writeFile(executable.compiledPath, content, (function(_this) {
    return function(err) {
      if (err != null) {
        return callback("Error while saving compiled executable " + executable.id + ": " + err);
      }
      logger.debug("executable " + executable.id + " successfully compiled");
      executables[executable.id] = executable;
      cleanNodeCache();
      if (!wasNew[executable.id]) {
        return callback(null);
      }
      return modelUtils.addConfKey(executable.id, 'names', executable.id, logger, callback);
    };
  })(this));
};

requireExecutable = function(executable, silent, callback) {
  var err, obj, previousMeta;
  previousMeta = _.clone(executable.meta);
  try {
    executable.meta = {
      kind: 'Script'
    };
    obj = require(pathUtils.relative(__dirname, executable.compiledPath));
    if ((obj != null) && utils.isA(obj, TurnRule)) {
      executable.meta.active = obj.active;
      executable.meta.rank = obj.rank;
      executable.meta.kind = 'TurnRule';
    } else if ((obj != null) && utils.isA(obj, Rule)) {
      executable.meta.active = obj.active;
      executable.meta.category = obj.category;
      executable.meta.kind = 'Rule';
    } else {
      executable.meta.kind = 'Script';
    }
  } catch (_error) {
    err = _error;
    return callback("failed to require executable " + executable.id + ": " + err);
  }
  if (!silent) {
    modelWatcher.change((wasNew[executable.id] ? 'creation' : 'update'), "Executable", executable);
    delete wasNew[executable.id];
  }
  return callback(null, executable);
};

search = function(query, all, _operator) {
  var candidates, field, i, ids, keys, match, results, term, tmp, value, _i, _len;
  if (_operator == null) {
    _operator = null;
  }
  if (Array.isArray(query)) {
    if (query.length < 2) {
      return "arrays must contains at least two terms";
    }
    results = [];
    for (i = _i = 0, _len = query.length; _i < _len; i = ++_i) {
      term = query[i];
      tmp = search(term, all);
      if (_operator === 'and' && i !== 0) {
        results = results.filter(function(result) {
          return -1 !== tmp.indexOf(result);
        });
      } else {
        results = results.concat(tmp.filter(function(result) {
          return -1 === results.indexOf(result);
        }));
      }
    }
    return results;
  }
  if ('object' === utils.type(query)) {
    keys = Object.keys(query);
    if (keys.length !== 1) {
      throw new Error("only one attribute is allowed inside query terms");
    }
    field = keys[0];
    value = query[field];
    if ('string' === utils.type(value)) {
      match = /^\/(.*)\/(i|m)?(i|m)?$/.exec(value);
      if (match != null) {
        value = new RegExp(match[1], match[2], match[3]);
      }
    }
    if (field === 'and' || field === 'or') {
      return search(value, all, field);
    } else {
      candidates = all.concat();
      if (field === 'category' || field === 'rank' || field === 'active') {
        candidates = all.map(function(candidate) {
          return require(path.relative(__dirname, candidate.compiledPath));
        });
      }
      ids = [];
      switch (utils.type(value)) {
        case 'string':
        case 'number':
        case 'boolean':
          candidates.forEach(function(candidate, i) {
            if (candidate[field] === value) {
              return ids.push(i);
            }
          });
          break;
        case 'regexp':
          candidates.filter(function(candidate, i) {
            if (value.test(candidate[field])) {
              return ids.push(i);
            }
          });
          break;
        default:
          throw new Error("" + field + ":" + value + " is not a valid value");
      }
      return all.filter(function(executable, i) {
        return __indexOf.call(ids, i) >= 0;
      });
    }
  } else {
    throw new Error("'" + query + "' is nor an array, nor an object");
  }
};

executables = {};

Executable = (function() {
  Executable.resetAll = function(clean, callback) {
    var removed;
    Item = require('../model/Item');
    cleanNodeCache();
    removed = _.keys(executables);
    executables = {};
    return utils.enforceFolder(compiledRoot, clean, logger, function(err) {
      if (err != null) {
        return callback(err);
      }
      return fs.readdir(root, function(err, files) {
        var readFile;
        if (err != null) {
          return callback("Error while listing executables: " + err);
        }
        readFile = function(file, end) {
          var executable, ext;
          ext = path.extname(file);
          if (__indexOf.call(supported, ext) < 0) {
            return end();
          }
          executable = new Executable({
            id: file.replace(ext, ''),
            lang: ext.slice(1)
          });
          return fs.readFile(executable.path, encoding, function(err, content) {
            if (err != null) {
              if (err.code === 'ENOENT') {
                return end();
              }
              return callback("Error while reading executable '" + executable.id + "': " + err);
            }
            executable.content = content;
            return compileFile(executable, function(err) {
              if (err != null) {
                return callback("Compilation failed: " + err);
              }
              return end();
            });
          });
        };
        return async.each(files, readFile, function(err) {
          if (err != null) {
            return callback(err);
          }
          return async.each(_.values(executables), function(executable, next) {
            return requireExecutable(executable, true, next);
          }, function(err) {
            var id, worker, _ref;
            if (err == null) {
              logger.debug('Local executables cached successfully reseted');
            }
            if (cluster.isMaster) {
              modelWatcher.emit('executableReset', removed);
              _ref = cluster.workers;
              for (id in _ref) {
                worker = _ref[id];
                worker.send({
                  event: 'executableReset'
                });
              }
            }
            return callback(err);
          });
        });
      });
    });
  };

  Executable.find = function(query, callback) {
    var executable, id, results;
    if ('function' === utils.type(query)) {
      callback = query;
      query = null;
    }
    results = [];
    for (id in executables) {
      executable = executables[id];
      results.push(executable);
    }
    if (query != null) {
      results = search(query, results);
    }
    return callback(null, results);
  };

  Executable.findCached = function(ids, callback) {
    var found, id;
    if (callback == null) {
      callback = null;
    }
    found = (function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = ids.length; _i < _len; _i++) {
        id = ids[_i];
        if (id in executables) {
          _results.push(executables[id]);
        }
      }
      return _results;
    })();
    if (callback == null) {
      return found;
    }
    return callback(null, found);
  };

  Executable.prototype.id = null;

  Executable.prototype.lang = 'coffee';

  Executable.prototype.meta = {};

  Executable.prototype.content = '';

  Executable.prototype.path = '';

  Executable.prototype.compiledPath = '';

  function Executable(attributes) {
    this.equals = __bind(this.equals, this);
    this.remove = __bind(this.remove, this);
    this.save = __bind(this.save, this);
    this.id = attributes.id;
    this.content = attributes.content || '';
    this.lang = attributes.lang || 'coffee';
    this.path = path.join(root, "" + this.id + "." + this.lang);
    this.compiledPath = path.join(compiledRoot, this.id + '.js');
  }

  Executable.prototype.save = function(callback) {
    wasNew[this.id] = !(this.id in executables);
    if (!modelUtils.isValidId(this.id)) {
      return callback(new Error("id " + this.id + " for model Executable is invalid"));
    }
    if (wasNew[this.id] && Item.isUsed(this.id)) {
      return callback(new Error("id " + this.id + " for model Executable is already used"));
    }
    return fs.writeFile(this.path, this.content, encoding, (function(_this) {
      return function(err) {
        if (err != null) {
          return callback("Error while saving executable " + _this.id + ": " + err);
        }
        logger.debug("executable " + _this.id + " successfully saved");
        return compileFile(_this, function(err) {
          if (err != null) {
            return callback(err);
          }
          return requireExecutable(_this, false, callback);
        });
      };
    })(this));
  };

  Executable.prototype.remove = function(callback) {
    return fs.exists(this.path, (function(_this) {
      return function(exists) {
        if (!exists) {
          return callback("Error while removing executable " + _this.id + ": this executable does not exists");
        }
        cleanNodeCache();
        delete executables[_this.id];
        return fs.unlink(_this.path, function(err) {
          if (err != null) {
            return callback("Error while removing executable " + _this.id + ": " + err);
          }
          return fs.unlink(_this.compiledPath, function(err) {
            logger.debug("executable " + _this.id + " successfully removed");
            modelWatcher.change('deletion', "Executable", _this);
            return callback(null, _this);
          });
        });
      };
    })(this));
  };

  Executable.prototype.equals = function(object) {
    if ('object' !== utils.type(object)) {
      return false;
    }
    return this.id === (object != null ? object.id : void 0);
  };

  return Executable;

})();

module.exports = Executable;
