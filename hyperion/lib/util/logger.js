
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
var EventEmitter, computeLevel, conf, dateFormat, emitter, format, fs, init, levelMaxLength, loggers, method, methods, moment, nameMaxLength, op, output, pathUtils, shim, utils, _, _ref, _s;

moment = require('moment');

_ = require('underscore');

_s = require('underscore.string');

fs = require('fs-extra');

pathUtils = require('path');

utils = require('../util/common');

EventEmitter = require('events').EventEmitter;

conf = null;

dateFormat = null;

nameMaxLength = null;

levelMaxLength = 5;

output = null;

loggers = {};

methods = {
  all: 0,
  log: 2,
  debug: 2,
  info: 3,
  warn: 4,
  error: 5,
  off: 6
};

emitter = new EventEmitter();

emitter.setMaxListeners(0);

init = function() {
  var isConsole;
  conf = utils.confKey('logger');
  dateFormat = conf.dateFormat || 'YYYYMMDDHHmmss';
  nameMaxLength = conf.nameMaxLength || 24;
  conf.levels = conf.levels || {};
  if (conf.path !== 'console') {
    isConsole = false;
    fs.mkdirsSync(pathUtils.dirname(conf.path));
    if (!!fs.existsSync(conf.path)) {
      fs.writeFileSync(conf.path, '');
    }
    return output = fs.createWriteStream(conf.path, {
      flags: 'a',
      encodinf: 'utf8'
    });
  } else {
    output = process.stdout;
    return isConsole = true;
  }
};

utils.on('confChanged', function() {
  var logger, name, _results;
  init();
  _results = [];
  for (name in loggers) {
    logger = loggers[name];
    _results.push(logger._level = computeLevel(name));
  }
  return _results;
});

init();

computeLevel = function(name) {
  var op;
  op = conf.defaultLevel;
  if (name in conf.levels) {
    op = conf.levels[name];
  }
  if (op in methods) {
    return methods[op];
  } else {
    return methods.off;
  }
};

format = function(args, level, name) {
  var arg, vals;
  vals = ((function() {
    var _i, _len, _results;
    if (_.isObject(arg)) {
      return JSON.stringify(arg);
    } else {
      _results = [];
      for (_i = 0, _len = args.length; _i < _len; _i++) {
        arg = args[_i];
        _results.push(arg != null ? arg.toString() : void 0);
      }
      return _results;
    }
  })());
  return "" + (moment().format(conf.dateFormat || defaultDateFormat)) + " " + process.pid + " " + (_s.pad(name, nameMaxLength)) + " " + (_s.pad(level, levelMaxLength)) + " : " + (vals.join(' '));
};

emitter.getLogger = function(name) {
  var logger, op;
  if (!(name in loggers)) {
    if (!name) {
      throw new Error('logger name is mandatory');
    }
    if (!(name.length <= nameMaxLength)) {
      throw new Error("logger with name " + name + " exceeds the maximum length of " + nameMaxLength);
    }
    logger = {
      _level: computeLevel(name),
      _name: name
    };
    for (op in methods) {
      if (op !== 'all' && op !== 'off') {
        logger[op] = (function(opName) {
          return function() {
            var args;
            args = Array.prototype.slice.call(arguments);
            if (methods[opName] >= this._level) {
              output.write("" + (format(args, opName, this._name)) + "\n");
              return emitter.emit('log', {
                level: opName,
                name: this._name,
                args: args
              });
            }
          };
        })(op);
      }
    }
    loggers[name] = logger;
  }
  return loggers[name];
};

if (((_ref = process.env) != null ? _ref.NODE_ENV : void 0) !== 'test') {
  shim = emitter.getLogger('console');
  for (op in shim) {
    method = shim[op];
    console[op] = method;
  }
  console.dir = console.log;
}

module.exports = emitter;
