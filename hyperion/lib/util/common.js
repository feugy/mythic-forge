
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
var EventEmitter, async, conf, confPath, emitter, fs, parseConf, pathUtils, yaml, _, _processOp, _processOpSync;

yaml = require('js-yaml');

fs = require('fs-extra');

pathUtils = require('path');

async = require('async');

_ = require('underscore');

EventEmitter = require('events').EventEmitter;

emitter = new EventEmitter();

emitter.setMaxListeners(0);

conf = null;

confPath = pathUtils.resolve("" + (process.cwd()) + "/conf/" + (process.env.NODE_ENV ? process.env.NODE_ENV : 'dev') + "-conf.yml");

parseConf = function() {
  var err;
  try {
    return conf = yaml.load(fs.readFileSync(confPath, 'utf8'));
  } catch (_error) {
    err = _error;
    throw new Error("Cannot read or parse configuration file '" + confPath + "': " + err);
  }
};

parseConf();

fs.watch(confPath, function() {
  return _.defer(function() {
    parseConf();
    return emitter.emit('confChanged');
  });
});

emitter.type = function(obj) {
  var _ref;
  return ((_ref = Object.prototype.toString.call(obj).slice(8, -1)) != null ? _ref.toLowerCase() : void 0) || 'undefined';
};

emitter.isA = function(obj, clazz) {
  var currentClass, _ref;
  if (!((obj != null) && (clazz != null))) {
    return false;
  }
  currentClass = obj.constructor;
  while (currentClass != null) {
    if (currentClass.name.toLowerCase() === clazz.name.toLowerCase()) {
      return true;
    }
    currentClass = (_ref = currentClass.__super__) != null ? _ref.constructor : void 0;
  }
  return false;
};

emitter.confKey = function(key, def) {
  var i, last, obj, path, step, _i, _len;
  path = key.split('.');
  obj = conf;
  last = path.length - 1;
  for (i = _i = 0, _len = path.length; _i < _len; i = ++_i) {
    step = path[i];
    if (!(step in obj)) {
      if (def === void 0) {
        throw new Error("The " + key + " key is not defined in the configuration file " + confPath);
      }
      return def;
    }
    if (i !== last) {
      obj = obj[step];
    } else {
      return obj[step];
    }
  }
};

emitter.enforceFolderSync = function(folderPath, forceRemove, logger) {
  var err, exists;
  if (forceRemove == null) {
    forceRemove = false;
  }
  if (logger == null) {
    logger = null;
  }
  exists = fs.existsSync(folderPath);
  if (forceRemove && exists) {
    fs.removeSync(folderPath);
    exists = false;
  }
  if (!exists) {
    try {
      fs.mkdirsSync(folderPath);
      return logger != null ? logger.info("Folder '" + folderPath + "' successfully created") : void 0;
    } catch (_error) {
      err = _error;
      console.trace();
      throw "Unable to create the folder '" + folderPath + "': " + err;
    }
  }
};

emitter.enforceFolder = function(folderPath, forceRemove, logger, callback) {
  return fs.exists(folderPath, function(exists) {
    var create;
    create = function(err) {
      if (err != null) {
        return callback("Failed to remove " + folderPath + ": " + err);
      }
      if (exists) {
        return callback(null);
      }
      return fs.mkdirs(folderPath, function(err) {
        if (err) {
          return callback("Failed to create " + folderPath + ": " + err);
        }
        if (logger != null) {
          logger.info("Folder '" + folderPath + "' successfully created");
        }
        return callback(null);
      });
    };
    if (forceRemove && exists) {
      exists = false;
      return fs.remove(folderPath, create);
    }
    return create();
  });
};

emitter.find = function(path, regex, contentRegEx, callback) {
  if ('function' === emitter.type(contentRegEx)) {
    callback = contentRegEx;
    contentRegEx = null;
  }
  return fs.stat(path, function(err, stats) {
    if (err != null) {
      return callback(err);
    }
    if (stats.isFile()) {
      if (!regex.test(path)) {
        return callback(null, []);
      }
      if (contentRegEx == null) {
        return callback(null, [path]);
      }
      return fs.readFile(path, function(err, content) {
        if (err != null) {
          return callback(err);
        }
        return callback(null, (contentRegEx.test(content) ? [path] : []));
      });
    } else {
      return fs.readdir(path, function(err, children) {
        var results;
        if (err != null) {
          return callback(err);
        }
        results = [];
        return async.forEach(children, function(child, next) {
          return emitter.find(pathUtils.join(path, child), regex, contentRegEx, function(err, subResults) {
            if (err != null) {
              return next(err);
            }
            results = results.concat(subResults);
            return next();
          });
        }, function(err) {
          if (err != null) {
            return callback(err);
          }
          return callback(null, results);
        });
      });
    }
  });
};

emitter.generateToken = function(length) {
  var rand, token;
  token = '';
  while (token.length < length) {
    rand = 48 + Math.floor(Math.random() * 43);
    if (rand >= 58 && rand <= 64) {
      continue;
    }
    token += String.fromCharCode(rand).toLowerCase();
  }
  return token;
};

_processOp = function(path, err, callback) {
  if (err == null) {
    return callback(null);
  }
  switch (err.code) {
    case 'EPERM':
      return fs.chmod(path, '755', function(err) {
        if (err != null) {
          return callback(new Error("failed to change " + path + " permission before removal: " + err));
        }
        return emitter.remove(path, callback);
      });
    case 'ENOTEMPTY':
    case 'EBUSY':
      return _.defer(function() {
        return emitter.remove(path, callback);
      }, 50);
    case 'ENOENT':
      return callback(null);
    default:
      return callback(new Error("failed to remove " + path + ": " + err));
  }
};

_processOpSync = function(path, err) {
  if (err == null) {
    return;
  }
  switch (err.code) {
    case 'EPERM':
      try {
        fs.chmodSync(path, '755');
        return emitter.removeSync(path);
      } catch (_error) {
        err = _error;
        throw new Error("failed to change " + path + " permission before removal: " + err);
      }
      break;
    case 'ENOTEMPTY':
    case 'EBUSY':
      return emitter.removeSync(path);
    case 'ENOENT':
      break;
    default:
      throw new Error("failed to remove " + path + ": " + err);
  }
};

emitter.remove = function(path, callback) {
  callback || (callback = function() {});
  return fs.stat(path, function(err, stats) {
    return _processOp(path, err, function(err) {
      if (stats == null) {
        return callback();
      }
      if (err != null) {
        return callback(err);
      }
      if (stats.isFile()) {
        return fs.unlink(path, function(err) {
          return _processOp(path, err, callback);
        });
      }
      return fs.readdir(path, function(err, contents) {
        var content;
        if (err != null) {
          return callback(new Error("failed to remove " + path + ": " + err));
        }
        return async.forEach((function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = contents.length; _i < _len; _i++) {
            content = contents[_i];
            _results.push(pathUtils.join(path, content));
          }
          return _results;
        })(), emitter.remove, function(err) {
          if (err != null) {
            return callback(err);
          }
          return fs.rmdir(path, function(err) {
            return _processOp(path, err, callback);
          });
        });
      });
    });
  });
};

emitter.removeSync = function(path) {
  var content, contents, err, stats, _i, _len;
  try {
    stats = fs.statSync(path);
    if (stats.isFile()) {
      try {
        return fs.unlinkSync(path);
      } catch (_error) {
        err = _error;
        return _processOpSync(path, err);
      }
    } else {
      contents = (function() {
        var _i, _len, _ref, _results;
        _ref = fs.readdirSync(path);
        _results = [];
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          content = _ref[_i];
          _results.push(pathUtils.join(path, content));
        }
        return _results;
      })();
      for (_i = 0, _len = contents.length; _i < _len; _i++) {
        content = contents[_i];
        emitter.removeSync(content);
      }
      try {
        return fs.rmdirSync(path);
      } catch (_error) {
        err = _error;
        return _processOpSync(path, err);
      }
    }
  } catch (_error) {
    err = _error;
    return _processOpSync(path, err);
  }
};

emitter.empty = function(path, callback) {
  return fs.readdir(path, function(err, files) {
    if (err != null) {
      return callback(err);
    }
    return async.forEachSeries(files, function(file, next) {
      return emitter.remove(pathUtils.join(path, file), next);
    }, function(err) {
      if (err != null) {
        return callback(err);
      }
      return _.defer(function() {
        return callback(null);
      }, 50);
    });
  });
};

emitter.relativePath = function(aPath, bPath) {
  var aLength, aPathSteps, bLength, bPathSteps, i, path, stepBack, suffix, _i, _j, _ref;
  aPath = pathUtils.normalize(aPath);
  aPathSteps = aPath.split(pathUtils.sep);
  aLength = aPathSteps.length;
  bPath = pathUtils.normalize(bPath);
  bPathSteps = bPath.split(pathUtils.sep);
  bLength = bPathSteps.length;
  suffix = '';
  stepBack = 0;
  if (0 === aPath.indexOf(bPath)) {
    stepBack = aLength - bLength;
  } else {
    for (i = _i = 0, _ref = bLength - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
      if (aPathSteps[i] === bPathSteps[i]) {
        if (i !== aLength - 1) {
          continue;
        }
        suffix = "." + pathUtils.sep + (bPathSteps.slice(i + 1, +bLength + 1 || 9e9).join(pathUtils.sep));
      } else {
        stepBack = aLength - i;
        if (i < bLength) {
          suffix = "" + pathUtils.sep + (bPathSteps.slice(i, +bLength + 1 || 9e9).join(pathUtils.sep));
        }
      }
      break;
    }
  }
  path = '';
  for (i = _j = 0; 0 <= stepBack ? _j < stepBack : _j > stepBack; i = 0 <= stepBack ? ++_j : --_j) {
    path += '..';
    if (i !== stepBack - 1) {
      path += pathUtils.sep;
    }
  }
  return "" + path + suffix;
};

emitter.purgeFolder = function(err, root) {
  if (emitter.isA(err, Error)) {
    err = err.message;
  }
  if ('string') {
    return err.replace(new RegExp("" + (root.replace(/\\/g, '\\\\')), 'g'), '');
  }
};

module.exports = emitter;
