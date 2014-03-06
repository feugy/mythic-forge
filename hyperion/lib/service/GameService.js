
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
var ClientConf, Event, EventType, Executable, Field, FieldType, GameService, Item, ItemType, apiBaseUrl, async, baseUrl, certPath, host, logger, merge, pathUtils, port, ruleService, ruleUtils, utils, _, _GameService, _instance,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

async = require('async');

_ = require('underscore');

Item = require('../model/Item');

Event = require('../model/Event');

Field = require('../model/Field');

ItemType = require('../model/ItemType');

EventType = require('../model/EventType');

FieldType = require('../model/FieldType');

Executable = require('../model/Executable');

ClientConf = require('../model/ClientConf');

utils = require('../util/common');

pathUtils = require('path');

ruleUtils = require('../util/rule');

ruleService = require('./RuleService').get();

logger = require('../util/logger').getLogger('service');

port = utils.confKey('server.bindingPort', utils.confKey('server.staticPort', process.env.PORT));

host = utils.confKey('server.host');

baseUrl = "http://" + host;

if (port !== 80) {
  baseUrl += ":" + port;
}

apiBaseUrl = "" + ((certPath = utils.confKey('ssl.certificate', null) != null) ? 'https' : 'http') + "://" + host + ":" + (utils.confKey('server.bindingPort', utils.confKey('server.apiPort')));

merge = function(result, original) {
  var attr, value, _results;
  _results = [];
  for (attr in original) {
    value = original[attr];
    if (!_.isArray(value) && _.isObject(value)) {
      if (result[attr] == null) {
        result[attr] = {};
      }
      _results.push(merge(result[attr], value));
    } else {
      _results.push(result[attr] = value);
    }
  }
  return _results;
};

_GameService = (function() {
  function _GameService() {
    this.getConf = __bind(this.getConf, this);
    this.getExecutables = __bind(this.getExecutables, this);
    this.importRules = __bind(this.importRules, this);
    this.executeRule = __bind(this.executeRule, this);
    this.resolveRules = __bind(this.resolveRules, this);
    this.consultMap = __bind(this.consultMap, this);
    this.getEvents = __bind(this.getEvents, this);
    this.getItems = __bind(this.getItems, this);
    this.getTypes = __bind(this.getTypes, this);
  }

  _GameService.prototype.getTypes = function(ids, callback) {
    var types;
    logger.debug("Consult types with ids: " + ids);
    types = [];
    return async.forEach([ItemType, EventType, FieldType], (function(_this) {
      return function(clazz, next) {
        return clazz.find({
          _id: {
            $in: ids
          }
        }, function(err, docs) {
          if (err != null) {
            return callback(err, null);
          }
          types = types.concat(docs);
          return next();
        });
      };
    })(this), function() {
      return callback(null, types);
    });
  };

  _GameService.prototype.getItems = function(ids, callback) {
    logger.debug("Consult items with ids: " + ids);
    return Item.find({
      _id: {
        $in: ids
      }
    }, function(err, items) {
      if (err != null) {
        return callback(err, null);
      }
      return Item.fetch(items, true, callback);
    });
  };

  _GameService.prototype.getEvents = function(ids, callback) {
    logger.debug("Consult events with ids: " + ids);
    return Event.find({
      _id: {
        $in: ids
      }
    }, function(err, events) {
      if (err != null) {
        return callback(err, null);
      }
      return Event.fetch(events, true, callback);
    });
  };

  _GameService.prototype.consultMap = function(mapId, lowX, lowY, upX, upY, callback) {
    if (!((mapId != null) && (lowX != null) && (lowY != null) && (upX != null) && (upY != null) && (callback != null))) {
      return callback('All parameters are mandatory');
    }
    logger.debug("Consult map " + mapId + " between " + lowX + ":" + lowY + " and " + upX + ":" + upY);
    return Item.where('map', mapId).where('x').gte(lowX).where('x').lte(upX).where('y').gte(lowY).where('y').lte(upY).exec(function(err, items) {
      if (err != null) {
        return callback(err, [], []);
      }
      return Field.where('mapId', mapId).where('x').gte(lowX).where('x').lte(upX).where('y').gte(lowY).where('y').lte(upY).exec(function(err, fields) {
        if (err != null) {
          return callback(err, [], []);
        }
        return callback(null, items, fields);
      });
    });
  };

  _GameService.prototype.resolveRules = function() {
    logger.debug('Trigger rules resolution');
    return ruleService.resolve.apply(ruleService, arguments);
  };

  _GameService.prototype.executeRule = function() {
    logger.debug('Trigger rules execution');
    return ruleService.execute.apply(ruleService, arguments);
  };

  _GameService.prototype.importRules = function() {
    logger.debug('Export rules to client');
    return ruleService["export"].apply(ruleService, arguments);
  };

  _GameService.prototype.getExecutables = function(callback) {
    logger.debug('Consult all executables');
    return Executable.find(callback);
  };

  _GameService.prototype.getConf = function(base, locale, callback) {
    var conf, def, ids;
    conf = {
      separator: pathUtils.sep,
      basePath: "" + base + "/",
      apiBaseUrl: apiBaseUrl,
      imagesUrl: "" + baseUrl + "/images/",
      timer: {
        value: ruleUtils.timer.current().valueOf(),
        paused: ruleUtils.timer.stopped
      }
    };
    ids = ['default'];
    if (locale != null) {
      ids.push(locale);
    }
    if ((locale != null) && -1 !== locale.indexOf('_')) {
      ids.push(locale.replace(/_\w*$/, ''));
    }
    return def = ClientConf.findCached(ids, (function(_this) {
      return function(err, confs) {
        var spec, _i, _len;
        if (err != null) {
          return callback("Failed to load client configurations: " + err);
        }
        def = _.findWhere(confs, {
          _id: 'default'
        });
        if (def != null) {
          merge(conf, def.values);
        }
        confs = _.chain(confs).without(def).sortBy('_id').value();
        for (_i = 0, _len = confs.length; _i < _len; _i++) {
          spec = confs[_i];
          merge(conf, spec.values);
        }
        return callback(null, conf);
      };
    })(this));
  };

  return _GameService;

})();

_instance = void 0;

GameService = (function() {
  function GameService() {}

  GameService.get = function() {
    return _instance != null ? _instance : _instance = new _GameService();
  };

  return GameService;

})();

module.exports = GameService;
