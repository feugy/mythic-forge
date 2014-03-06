
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
var EventEmitter, ModelWatcher, gameClientRoot, logger, pathUtils, utils, _, _ModelWatcher,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

_ = require('underscore');

pathUtils = require('path');

utils = require('../util/common');

logger = require('../util/logger').getLogger('watcher');

EventEmitter = require('events').EventEmitter;

gameClientRoot = utils.confKey('game.client.dev');

_ModelWatcher = (function(_super) {
  __extends(_ModelWatcher, _super);

  function _ModelWatcher() {
    this.change = __bind(this.change, this);
    return _ModelWatcher.__super__.constructor.apply(this, arguments);
  }

  _ModelWatcher.prototype.change = function(operation, className, instance, modified) {
    var changes, key, path, value, _i, _len, _ref, _ref1;
    changes = {};
    if ('_doc' in instance) {
      _ref = instance._doc;
      for (key in _ref) {
        if (!__hasProp.call(_ref, key)) continue;
        value = _ref[key];
        changes[key] = value;
      }
    } else {
      changes = _.clone(instance);
    }
    if (changes._id != null) {
      changes.id = changes._id;
      delete changes._id;
    }
    delete changes.__v;
    if (className === 'Item' || className === 'Event') {
      changes.type = (_ref1 = changes.type) != null ? _ref1.id : void 0;
    }
    if (modified && __indexOf.call(modified, 'map') >= 0 && (className === 'Item' || className === 'Field')) {
      if (changes.map == null) {
        changes.map = null;
      } else {
        if ('object' === utils.type(changes.map)) {
          changes.map = changes.map.id;
        }
      }
    }
    if (operation === 'update') {
      if (className !== 'Executable' && className !== 'FSItem') {
        changes = {
          id: instance.id
        };
        for (_i = 0, _len = modified.length; _i < _len; _i++) {
          path = modified[_i];
          changes[path] = instance.get(path);
          if (changes[path] == null) {
            changes[path] = null;
          }
        }
      }
    } else if (operation !== 'creation' && operation !== 'deletion') {
      throw new Error("Unknown operation " + operation + " on instance " + (changes.id || changes.path) + "}");
    }
    if (className === 'FSItem') {
      changes.path = pathUtils.relative(gameClientRoot, changes.path);
    }
    if (className === 'Player') {
      require('../model/Player').purge(changes);
      if (Object.keys(changes).length === 0) {
        return;
      }
    }
    logger.debug("change propagation: " + operation + " of instance " + (changes.id || changes.path) + " (" + className + "): " + (_.keys(changes || {})));
    return this.emit('change', operation, className, changes);
  };

  return _ModelWatcher;

})(EventEmitter);

ModelWatcher = (function() {
  var _instance;

  function ModelWatcher() {}

  _instance = void 0;

  ModelWatcher.get = function() {
    if (_instance == null) {
      _instance = new _ModelWatcher();
    }
    _instance.setMaxListeners(20);
    return _instance;
  };

  return ModelWatcher;

})();

module.exports = ModelWatcher;
