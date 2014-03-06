
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
var Model, ObjectId, async, checkObject, checkPropertyType, checkString, filterModified, getProp, utils, watcher, _,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

_ = require('underscore');

async = require('async');

ObjectId = require('mongodb').BSONPure.ObjectID;

Model = require('mongoose').Model;

watcher = require('../model/ModelWatcher').get();

utils = require('../util/common');

checkString = function(val, property) {
  if (!(val === null || 'string' === utils.type(val))) {
    return "'" + val + "' isn't a valid " + property.type;
  } else {
    return null;
  }
};

checkObject = function(val, property) {
  var _ref;
  if (val === null || 'string' === utils.type(val)) {
    return null;
  } else if ('object' === utils.type(val)) {
    if (!((val != null ? (_ref = val.collection) != null ? _ref.name : void 0 : void 0) === ("" + (property.def.toLowerCase()) + "s") || property.def.toLowerCase() === 'any' && utils.isA(val, Model))) {
      return "" + val + " isn't a valid " + property.def;
    } else {
      return null;
    }
  } else {
    return "" + val + " isn't a valid " + property.def;
  }
};

checkPropertyType = function(value, property) {
  var err, obj, strVal, _i, _len;
  err = null;
  switch (property.type) {
    case 'integer':
      if (!(value === null || ('number' === utils.type(value) && parseFloat(value, 10) === parseInt(value, 10)))) {
        err = "" + value + " isn't a valid integer";
      }
      break;
    case 'float':
      if (!(value === null || ('number' === utils.type(value) && !isNaN(parseFloat(value, 10))))) {
        err = "" + value + " isn't a valid float";
      }
      break;
    case 'boolean':
      strVal = ("" + value).toLowerCase();
      if (value !== null && ('array' === utils.type(value) || 'string' === utils.type(value) || (strVal !== 'true' && strVal !== 'false'))) {
        err = "" + value + " isn't a valid boolean";
      }
      break;
    case 'date':
    case 'time':
    case 'datetime':
      if (value !== null) {
        if ('string' === utils.type(value)) {
          if (isNaN(new Date(value).getTime())) {
            err = "" + value + " isn't a valid date";
          }
        } else if ('date' !== utils.type(value) || isNaN(value.getTime())) {
          err = "" + value + " isn't a valid date";
        }
      }
      break;
    case 'object':
      err = checkObject(value, property);
      break;
    case 'array':
      if (Array.isArray(value)) {
        for (_i = 0, _len = value.length; _i < _len; _i++) {
          obj = value[_i];
          err = checkObject(obj, property);
        }
      } else {
        err = "" + value + " isn't a valid array of " + property.def;
      }
      break;
    case 'string':
      err = checkString(value, property);
      break;
    case 'text':
      err = checkString(value, property);
      break;
    default:
      err = "" + property.type + " isn't a valid type";
  }
  return err;
};

getProp = function(obj, path, callback) {
  var processStep, steps;
  if ('string' !== utils.type(path)) {
    return callback("invalid path '" + path + "'");
  }
  steps = path.split('.');
  processStep = function(obj) {
    var bracket, bracketEnd, endStep, index, step, subObj, _ref, _ref1, _ref2, _ref3, _ref4, _ref5;
    step = steps.splice(0, 1)[0];
    bracket = step.indexOf('[');
    index = -1;
    if (bracket !== -1) {
      bracketEnd = step.indexOf(']', bracket);
      if (bracketEnd > bracket) {
        index = parseInt(step.substring(bracket + 1, bracketEnd));
        step = step.substring(0, bracket);
      }
    }
    if (!('object' === utils.type(obj) && step in obj)) {
      return callback(null, void 0);
    }
    subObj = index !== -1 ? obj[step][index] : obj[step];
    endStep = function() {
      if (steps.length === 0) {
        return callback(null, subObj);
      } else {
        return processStep(subObj);
      }
    };
    if (((_ref = obj.type) != null ? (_ref1 = _ref.properties) != null ? (_ref2 = _ref1[step]) != null ? _ref2.type : void 0 : void 0 : void 0) === 'object' || ((_ref3 = obj.type) != null ? (_ref4 = _ref3.properties) != null ? (_ref5 = _ref4[step]) != null ? _ref5.type : void 0 : void 0 : void 0) === 'array') {
      if (('array' === utils.type(subObj) && 'string' === utils.type(subObj != null ? subObj[0] : void 0)) || 'string' === utils.type(subObj)) {
        return obj.fetch(function(err, obj) {
          if (err != null) {
            return callback("error on loading step " + step + " along path " + path + ": " + err);
          }
          subObj = index !== -1 ? obj[step][index] : obj[step];
          return endStep();
        });
      } else {
        return endStep();
      }
    } else {
      return endStep();
    }
  };
  return processStep(obj);
};

filterModified = function(obj, modified, _parsed) {
  var def, prop, properties, value, values, _i, _len, _ref, _results;
  if (_parsed == null) {
    _parsed = [];
  }
  if (__indexOf.call(_parsed, obj) >= 0) {
    return;
  }
  _parsed.push(obj);
  if (obj != null ? typeof obj.isModified === "function" ? obj.isModified() : void 0 : void 0) {
    modified.push(obj);
  }
  if ((obj != null ? obj._className : void 0) === 'Player') {
    _ref = obj.characters;
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      value = _ref[_i];
      if ((value != null) && 'string' !== utils.type(value)) {
        filterModified(value, modified, _parsed);
      }
    }
    return;
  }
  if (!((obj != null ? obj._className : void 0) === 'Item' || (obj != null ? obj._className : void 0) === 'Event')) {
    return;
  }
  properties = obj.type.properties;
  _results = [];
  for (prop in properties) {
    def = properties[prop];
    if (def.type === 'object') {
      value = obj[prop];
      if ((value != null) && 'string' !== utils.type(value)) {
        _results.push(filterModified(value, modified, _parsed));
      } else {
        _results.push(void 0);
      }
    } else if (def.type === 'array') {
      values = obj[prop];
      if (values) {
        _results.push((function() {
          var _j, _len1, _results1;
          _results1 = [];
          for (_j = 0, _len1 = values.length; _j < _len1; _j++) {
            value = values[_j];
            if ((value != null) && 'string' !== utils.type(value)) {
              _results1.push(filterModified(value, modified, _parsed));
            }
          }
          return _results1;
        })());
      } else {
        _results.push(void 0);
      }
    } else {
      _results.push(void 0);
    }
  }
  return _results;
};

module.exports = {
  generateId: (function(_this) {
    return function() {
      return new ObjectId().toString();
    };
  })(this),
  purgeDuplicates: (function(_this) {
    return function(arr) {
      var i, length, model, uniq, _results;
      uniq = [];
      length = arr.length;
      i = 0;
      _results = [];
      while (i < length) {
        model = arr[i];
        if ((model.id != null) && _.any(uniq, function(obj) {
          return (obj != null ? obj.equals : void 0) && obj.equals(model);
        })) {
          arr.splice(i, 1);
          _results.push(length--);
        } else {
          uniq.push(model);
          _results.push(i++);
        }
      }
      return _results;
    };
  })(this),
  checkPropertyType: checkPropertyType,
  checkParameters: function(actual, expected, actor, target, callback) {
    if (!(Array.isArray(expected) && expected.length > 0)) {
      return callback(null);
    }
    return async.forEach(expected, function(param, next) {
      var ids, max, min, obj, possibles, process, values, _i, _len, _ref;
      if ('object' !== utils.type(param)) {
        return next("invalid expected parameter " + param);
      }
      if (!('string' === utils.type(param.name) && 'string' === utils.type(param.type))) {
        return next("invalid name or type within expected parameter " + (JSON.stringify(param)));
      }
      if ((actual != null ? actual[param.name] : void 0) == null) {
        return next("missing parameter " + param.name);
      }
      values = Array.isArray(actual[param.name]) ? actual[param.name] : [actual[param.name]];
      min = param.numMin != null ? param.numMin : 1;
      max = param.numMax != null ? param.numMax : 1;
      if (values.length < min) {
        return next("" + param.name + ": expected at least " + min + " value(s)");
      }
      if (values.length > max) {
        return next("" + param.name + ": expected at most " + max + " value(s)");
      }
      process = function(possibles) {
        var err, id, objValue, qty, value, _i, _len;
        for (_i = 0, _len = values.length; _i < _len; _i++) {
          value = values[_i];
          if (param.type !== 'object') {
            err = checkPropertyType(value, param);
            if (err != null) {
              return next("" + param.name + ": " + err);
            }
          }
          switch (param.type) {
            case 'integer':
            case 'float':
              if ('number' === utils.type(param.min)) {
                if (value < param.min) {
                  return next("" + param.name + ": " + value + " is lower than " + param.min);
                }
              }
              if ('number' === utils.type(param.max)) {
                if (value > param.max) {
                  return next("" + param.name + ": " + value + " is higher than " + param.max);
                }
              }
              break;
            case 'date':
            case 'time':
            case 'datetime':
              if ('date' === utils.type(param.min)) {
                if (value.getTime() < param.min.getTime()) {
                  return next("" + param.name + ": " + value + " is lower than " + param.min);
                }
              }
              if ('date' === utils.type(param.max)) {
                if (value.getTime() > param.max.getTime()) {
                  return next("" + param.name + ": " + value + " is higher than " + param.max);
                }
              }
              break;
            case 'string':
              if (Array.isArray(param.within)) {
                if (__indexOf.call(param.within, value) < 0) {
                  return next("" + param.name + ": " + value + " is not a valid option");
                }
              }
              if ('string' === utils.type(param.match)) {
                if (!new RegExp(param.match).test(value)) {
                  return next("" + param.name + ": " + value + " does not match conditions");
                }
              }
              break;
            case 'object':
              id = null;
              qty = null;
              if ('string' === utils.type(value)) {
                id = value;
              } else if ('object' === utils.type(value) && 'string' === utils.type(value.id) && 'number' === utils.type(value.qty)) {
                id = value.id;
                qty = value.qty;
                if (qty <= 0) {
                  return next("" + param.name + ": quantity must be a positive number");
                }
              } else {
                return next("" + param.name + ": " + (JSON.stringify(value)) + " isn't a valid object id or id+qty");
              }
              objValue = _.find(possibles, function(obj) {
                return id === (obj != null ? obj.id : void 0);
              });
              if (objValue == null) {
                return next("" + param.name + ": " + id + " is not a valid option");
              }
              if (objValue.type.quantifiable && qty === null) {
                return next("" + param.name + ": " + id + " is missing quantity");
              }
              if (qty > objValue.quantity) {
                return next("" + param.name + ": not enought " + id + " to honor quantity " + qty);
              }
          }
        }
        return next(null);
      };
      if (param.type !== 'object') {
        return process();
      }
      if (Array.isArray(param.within)) {
        possibles = [];
        ids = [];
        _ref = param.within;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          obj = _ref[_i];
          if (utils.isA(obj, Model)) {
            possibles.push(obj);
          } else {
            if ('string' === utils.type(obj)) {
              ids.push(obj);
            }
          }
        }
        if (ids.length === 0) {
          return process(possibles);
        }
        return require('../model/Item').findCached(ids, function(err, objs) {
          if (err != null) {
            return next("" + param.name + ": failed to resolve possible items: " + err);
          }
          ids = _.difference(ids, _.pluck(objs, 'id'));
          possibles = possibles.concat(objs);
          if (ids.length === 0) {
            return process(possibles);
          }
          return require('../model/Event').findCached(ids, function(err, objs) {
            if (err != null) {
              return next("" + param.name + ": failed to resolve possible events: " + err);
            }
            ids = _.difference(ids, _.pluck(objs, 'id'));
            possibles = possibles.concat(objs);
            return process(possibles);
          });
        });
      }
      if ('object' === utils.type(param.property) && (param.property.path != null) && (param.property.from != null)) {
        return getProp((param.property.from === 'target' ? target : actor), param.property.path, function(err, objs) {
          if (err != null) {
            return next("" + param.name + ": failed to resolve possible values: " + err);
          }
          return process(objs);
        });
      }
      return next("missing 'within' constraint or invalid 'property' constraint (" + (JSON.stringify(param)) + ") for parameter " + param.name);
    }, function(err) {
      return callback(err || null);
    });
  },
  processLinks: function(instance, properties, markModified) {
    var i, linked, name, property, value, _i, _len, _results;
    if (markModified == null) {
      markModified = true;
    }
    _results = [];
    for (name in properties) {
      property = properties[name];
      value = instance._doc[name];
      if (property.type === 'object') {
        if (value !== null && 'object' === utils.type(value) && ((value != null ? value.id : void 0) != null)) {
          instance._doc[name] = value.id;
          _results.push(instance.markModified(name));
        } else {
          _results.push(void 0);
        }
      } else if (property.type === 'array') {
        if ('array' === utils.type(value)) {
          for (i = _i = 0, _len = value.length; _i < _len; i = ++_i) {
            linked = value[i];
            if (!('object' === utils.type(linked) && ((linked != null ? linked.id : void 0) != null))) {
              continue;
            }
            value[i] = linked.id;
            instance.markModified(name);
          }
          _results.push(instance._doc[name] = _.filter(value, function(obj) {
            return obj != null;
          }));
        } else {
          _results.push(void 0);
        }
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  },
  getProp: getProp,
  filterModified: filterModified,
  isValidId: function(id) {
    if ('string' !== utils.type(id)) {
      return false;
    }
    if (!id.match(/^[\w$-]+$/)) {
      return false;
    }
    return true;
  },
  addConfKey: function(key, parentKey, value, logger, callback) {
    return require('../model/ClientConf').findCached(['default'], (function(_this) {
      return function(err, confs) {
        var parent;
        if (!((err != null) || (confs != null ? confs.length : void 0) !== 0)) {
          err = 'not found';
        }
        if (err != null) {
          logger.error("failed to enrich default configuration: " + err);
          return callback();
        }
        parent = confs[0].values;
        if (parentKey != null) {
          if ('object' !== utils.type(parent[parentKey])) {
            parent[parentKey] = {};
          }
          parent = parent[parentKey];
        }
        parent[key] = value;
        return confs[0].save(function(err, saved) {
          if (err != null) {
            logger.error("failed to enrich default configuration: " + err);
          }
          return callback();
        });
      };
    })(this));
  }
};
