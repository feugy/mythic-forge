
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
var Event, EventType, Executable, FieldType, Item, ItemType, Map, Player, SearchService, async, enhanceTypeQuery, logger, utils, validateQuery, _, _SearchService, _instance,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

ItemType = require('../model/ItemType');

Item = require('../model/Item');

FieldType = require('../model/FieldType');

EventType = require('../model/EventType');

Event = require('../model/Event');

Map = require('../model/Map');

Executable = require('../model/Executable');

Player = require('../model/Player');

utils = require('../util/common');

async = require('async');

_ = require('underscore');

logger = require('../util/logger').getLogger('service');

validateQuery = function(query) {
  var err, keys, term, value, _i, _len;
  if (Array.isArray(query)) {
    if (query.length < 2) {
      return "arrays must contains at least two terms";
    }
    for (_i = 0, _len = query.length; _i < _len; _i++) {
      term = query[_i];
      err = validateQuery(term);
      if (err != null) {
        return err;
      }
    }
  } else if ('object' === utils.type(query)) {
    keys = Object.keys(query);
    if (keys.length !== 1) {
      return "only one attribute is allowed inside query terms";
    }
    value = query[keys[0]];
    if (keys[0] === 'and' || keys[0] === 'or') {
      return validateQuery(value);
    } else {
      switch (utils.type(value)) {
        case 'string':
        case 'number':
        case 'boolean':
        case 'regexp':
          return null;
        default:
          return "" + keys[0] + ":" + value + " is not a valid value";
      }
    }
  } else {
    return "'" + query + "' is nor an array, nor an object";
  }
};

enhanceTypeQuery = function(query) {
  var attr, match, term, value, _i, _len, _results;
  if (Array.isArray(query)) {
    _results = [];
    for (_i = 0, _len = query.length; _i < _len; _i++) {
      term = query[_i];
      _results.push(enhanceTypeQuery(term));
    }
    return _results;
  } else {
    attr = Object.keys(query)[0];
    value = query[attr];
    if ('string' === utils.type(value)) {
      match = /^\/(.*)\/(i|m)?(i|m)?$/.exec(value);
      if (match != null) {
        value = new RegExp(match[1], match[2], match[3]);
      }
    }
    switch (attr) {
      case 'and':
      case 'or':
        query["$" + attr] = value;
        delete query[attr];
        return enhanceTypeQuery(value);
      case 'id':
        query._id = value;
        return delete query.id;
      case 'quantifiable':
      case 'kind':
        break;
      default:
        delete query[attr];
        attr = "properties." + attr;
        if (value === '!') {
          return query[attr] = {
            $exists: true
          };
        } else {
          return query["" + attr + ".def"] = value;
        }
    }
  }
};

_SearchService = (function() {
  function _SearchService() {
    this.searchInstances = __bind(this.searchInstances, this);
    this.searchTypes = __bind(this.searchTypes, this);
    this._enhanceInstanceQuery = __bind(this._enhanceInstanceQuery, this);
  }

  _SearchService.prototype._enhanceInstanceQuery = function(query, callback) {
    var attr, match, subQuery, value;
    if (Array.isArray(query)) {
      return async.forEachSeries(query, (function(_this) {
        return function(term, next) {
          return _this._enhanceInstanceQuery(term, next);
        };
      })(this), callback);
    } else {
      attr = Object.keys(query)[0];
      value = query[attr];
      if ('string' === utils.type(value)) {
        match = /^\/(.*)\/(i|m)?(i|m)?$/.exec(value);
        if (match != null) {
          query[attr] = new RegExp(match[1], match[2], match[3]);
        }
      }
      switch (attr) {
        case 'and':
        case 'or':
          delete query[attr];
          query["$" + attr] = value;
          return this._enhanceInstanceQuery(value, callback);
        case 'id':
        case 'map':
        case 'type':
        case 'from':
        case 'characters':
          if (value === '!' && attr !== 'characters') {
            value = {
              $exists: true
            };
          } else if (value === '!') {
            value = {
              $elemMatch: {
                $exists: true
              }
            };
          } else {
            value = query[attr];
          }
          if (attr === 'id') {
            delete query.id;
            query._id = value;
          } else {
            query[attr] = value;
          }
          break;
        default:
          if (value === '!' && !attr.match(/^\w*\./)) {
            query[attr] = {
              $ne: null
            };
          }
          if (!(attr.match(/^prefs\./)) && attr.match(/^\w*\./)) {
            subQuery = {};
            match = attr.match(/^(\w*)\.(.*)$/);
            subQuery[match[2]] = query[attr];
            delete query[attr];
            if (match[1] === 'map' || match[1] === 'type') {
              return this.searchTypes(subQuery, (function(_this) {
                return function(err, results) {
                  if (err != null) {
                    return callback(err);
                  }
                  query[match[1]] = {
                    $in: _.pluck(results, 'id')
                  };
                  return callback(null);
                };
              })(this));
            } else {
              return this.searchInstances(subQuery, (function(_this) {
                return function(err, results) {
                  var ids, _ref;
                  if (err != null) {
                    return callback(err);
                  }
                  ids = (_ref = match[1]) === 'from' || _ref === 'characters' ? _.pluck(results, 'id') : _.chain(results).pluck('id').value();
                  query[match[1]] = {
                    $in: ids
                  };
                  return callback(null);
                };
              })(this));
            }
          }
      }
    }
    return callback(null);
  };

  _SearchService.prototype.searchTypes = function(query, callback) {
    var err, exc, results, search;
    if ('string' === utils.type(query)) {
      try {
        query = JSON.parse(query);
      } catch (_error) {
        exc = _error;
        return callback("Failed to parse query: " + exc);
      }
    }
    err = validateQuery(query);
    if (err != null) {
      return callback("Failed to parse query: " + err);
    }
    results = [];
    search = (function(_this) {
      return function(collection, next) {
        return collection.find(query, function(err, collResults) {
          if (err != null) {
            return callback("Failed to execute query: " + err);
          }
          results = results.concat(collResults);
          return next();
        });
      };
    })(this);
    return search(Executable, (function(_this) {
      return function() {
        enhanceTypeQuery(query);
        return async.forEach([ItemType, EventType, FieldType, Map], search, function(err) {
          return callback(null, results);
        });
      };
    })(this));
  };

  _SearchService.prototype.searchInstances = function(query, callback) {
    var err, exc, results;
    if ('string' === utils.type(query)) {
      try {
        query = JSON.parse(query);
      } catch (_error) {
        exc = _error;
        return callback("Failed to parse query: " + exc);
      }
    }
    err = validateQuery(query);
    if (err != null) {
      return callback("Failed to parse query: " + err);
    }
    results = [];
    return this._enhanceInstanceQuery(query, (function(_this) {
      return function(err) {
        if (err != null) {
          return callback("Failed to enhance query: " + err);
        }
        return async.forEach([Item, Event, Player], function(collection, next) {
          return collection.find(query, function(err, collResults) {
            if (err != null) {
              return next("Failed to execute query: " + err);
            }
            results = results.concat(collResults);
            return next();
          });
        }, function(err) {
          if (err != null) {
            return callback(err);
          }
          return callback(null, results);
        });
      };
    })(this));
  };

  return _SearchService;

})();

_instance = void 0;

SearchService = (function() {
  function SearchService() {}

  SearchService.get = function() {
    return _instance != null ? _instance : _instance = new _SearchService();
  };

  return SearchService;

})();

module.exports = SearchService;
