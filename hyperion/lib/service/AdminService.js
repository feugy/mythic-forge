
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
var AdminService, ClientConf, Event, EventType, Executable, Field, FieldType, Item, ItemType, Map, Player, authoringService, listSupported, logger, modelUtils, playerService, supported, utils, _, _AdminService, _instance,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

_ = require('underscore');

ItemType = require('../model/ItemType');

FieldType = require('../model/FieldType');

EventType = require('../model/EventType');

Map = require('../model/Map');

Field = require('../model/Field');

Item = require('../model/Item');

Event = require('../model/Event');

Player = require('../model/Player');

Executable = require('../model/Executable');

ClientConf = require('../model/ClientConf');

utils = require('../util/common');

modelUtils = require('../util/model');

logger = require('../util/logger').getLogger('service');

playerService = require('./PlayerService').get();

authoringService = require('./AuthoringService').get();

supported = ['Field', 'Item', 'Event', 'Player', 'ClientConf', 'ItemType', 'Executable', 'FieldType', 'Map', 'EventType', 'FSItem'];

listSupported = supported.slice(4);

_AdminService = (function() {
  function _AdminService() {
    this.remove = __bind(this.remove, this);
    this.save = __bind(this.save, this);
    this.list = __bind(this.list, this);
    this.isIdValid = __bind(this.isIdValid, this);
    ClientConf.findOne({
      _id: 'default'
    }, (function(_this) {
      return function(err, result) {
        if (err != null) {
          throw "Unable to check default configuration existence: " + err;
        }
        if (result != null) {
          return logger.info('"default" configuration already exists');
        }
        return new ClientConf({
          id: 'default'
        }).save(function(err) {
          if (err != null) {
            throw "Unable to create \"default\" configuration: " + err;
          }
          return logger.info('"default" client configuration has been created');
        });
      };
    })(this));
  }

  _AdminService.prototype.isIdValid = function(id, callback) {
    if (!modelUtils.isValidId(id)) {
      return callback("" + id + " is invalid");
    }
    if (ItemType.isUsed(id)) {
      return callback("" + id + " is already used");
    }
    return callback(null);
  };

  _AdminService.prototype.list = function(modelName, callback) {
    if (__indexOf.call(listSupported, modelName) < 0) {
      return callback("The " + modelName + " model can't be listed", modelName);
    }
    switch (modelName) {
      case 'ItemType':
        return ItemType.find(function(err, result) {
          return callback(err, modelName, result);
        });
      case 'FieldType':
        return FieldType.find(function(err, result) {
          return callback(err, modelName, result);
        });
      case 'EventType':
        return EventType.find(function(err, result) {
          return callback(err, modelName, result);
        });
      case 'Executable':
        return Executable.find(function(err, result) {
          return callback(err, modelName, result);
        });
      case 'Map':
        return Map.find(function(err, result) {
          return callback(err, modelName, result);
        });
      case 'ClientConf':
        return ClientConf.find(function(err, result) {
          return callback(err, modelName, result);
        });
      case 'FSItem':
        return authoringService.readRoot(function(err, root) {
          if (err == null) {
            return callback(err, modelName, root.content);
          }
        });
    }
  };

  _AdminService.prototype.save = function(modelName, values, email, callback) {
    var model, modelClass, populateTypeAndSave, resolveFrom, savedFields, unqueue, _save;
    if (__indexOf.call(supported, modelName) < 0) {
      return callback("The " + modelName + " model can't be saved", modelName);
    }
    _save = function(model) {
      return model.save(function(err, saved) {
        return callback(err, modelName, modelName === 'Player' ? Player.purge(saved) : saved);
      });
    };
    modelClass = null;
    switch (modelName) {
      case 'ClientConf':
        if (values.id == null) {
          values.id = 'default';
        }
        modelClass = ClientConf;
        break;
      case 'ItemType':
        modelClass = ItemType;
        break;
      case 'EventType':
        modelClass = EventType;
        break;
      case 'FieldType':
        modelClass = FieldType;
        break;
      case 'Executable':
        modelClass = Executable;
        break;
      case 'Map':
        modelClass = Map;
        break;
      case 'Player':
        modelClass = Player;
        break;
      case 'Item':
        populateTypeAndSave = function(model) {
          var _ref;
          return ItemType.findCached([model != null ? (_ref = model.type) != null ? _ref.id : void 0 : void 0], function(err, types) {
            var _ref1;
            if (err != null) {
              return callback("Failed to save item " + values.id + ". Error while resolving its type: " + err);
            }
            if (types.length !== 1) {
              return callback("Failed to save item " + values.id + " because there is no type with id " + (values != null ? (_ref1 = values.type) != null ? _ref1.id : void 0 : void 0));
            }
            model.type = types[0];
            return _save(model);
          });
        };
        if ('id' in values && Item.isUsed(values.id)) {
          return Item.findCached([values.id], function(err, models) {
            var key, model, value, _ref, _ref1, _ref2;
            if ((err != null) || models.length === 0) {
              return callback("Unexisting Item with id " + values.id + ": " + err, modelName);
            }
            model = models[0];
            for (key in values) {
              value = values[key];
              if (key !== 'id' && key !== 'type' && key !== 'map') {
                model[key] = value;
              }
            }
            if (((_ref = model.map) != null ? _ref.id : void 0) !== ((_ref1 = values.map) != null ? _ref1.id : void 0)) {
              if ((_ref2 = values.map) != null ? _ref2.id : void 0) {
                return Map.findCached([values.map.id], function(err, maps) {
                  if (err != null) {
                    return callback("Failed to save item " + values.id + ". Error while resolving its map: " + err);
                  }
                  if (maps.length !== 1) {
                    return callback("Failed to save item " + values.id + " because there is no map with id " + item.map);
                  }
                  model.map = maps[0];
                  return populateTypeAndSave(model);
                });
              } else {
                model.map = null;
                return populateTypeAndSave(model);
              }
            } else {
              return populateTypeAndSave(model);
            }
          });
        } else {
          model = new Item(values);
          return populateTypeAndSave(model);
        }
        break;
      case 'Event':
        populateTypeAndSave = function(model) {
          var _ref;
          return EventType.findCached([model != null ? (_ref = model.type) != null ? _ref.id : void 0 : void 0], function(err, types) {
            var _ref1;
            if (err != null) {
              return callback("Failed to save event " + values.id + ". Error while resolving its type: " + err);
            }
            if (types.length !== 1) {
              return callback("Failed to save event " + values.id + " because there is no type with id " + (values != null ? (_ref1 = values.type) != null ? _ref1.id : void 0 : void 0));
            }
            model.type = types[0];
            return _save(model);
          });
        };
        resolveFrom = function(model) {
          var id, _ref;
          if (model.from != null) {
            id = 'object' === utils.type(model.from) ? (_ref = model.from) != null ? _ref.id : void 0 : model.from;
            return Item.findCached([id], function(err, froms) {
              if (err != null) {
                return callback("Failed to save event " + values.id + ". Error while resolving its from: " + err);
              }
              if (froms.length !== 1) {
                return callbacl("Failed to save event " + values.id + " because there is no from with id " + id);
              }
              model.from = froms[0];
              return populateTypeAndSave(model);
            });
          } else {
            model.from = null;
            return populateTypeAndSave(model);
          }
        };
        if ('id' in values && Event.isUsed(values.id)) {
          return Event.findCached([values.id], function(err, models) {
            var key, value;
            if ((err != null) || models.length === 0) {
              return callback("Unexisting Item with id " + values.id + ": " + err, modelName);
            }
            model = models[0];
            for (key in values) {
              value = values[key];
              if (key !== 'id' && key !== 'type') {
                model[key] = value;
              }
            }
            return resolveFrom(model);
          });
        } else {
          model = new Event(values);
          return resolveFrom(model);
        }
        break;
      case 'Field':
        if (!Array.isArray(values)) {
          return callback('Fields must be saved within an array', modelName);
        }
        savedFields = [];
        unqueue = function(err, saved) {
          var field;
          if (saved != null) {
            savedFields.push(saved);
          }
          if (values.length === 0) {
            return callback(err, modelName, savedFields);
          }
          field = values.pop();
          if ('toObject' in field && field.toObject instanceof Function) {
            field = field.toObject();
          }
          if ('id' in field) {
            return callback('Fields cannot be updated', modelName, savedFields);
          }
          return new Field(field).save(unqueue);
        };
        return unqueue(null, null);
      case 'FSItem':
        return authoringService.save(values, email, function(err, saved) {
          return callback(err, modelName, saved);
        });
    }
    if ('toObject' in values && values.toObject instanceof Function) {
      values = values.toObject();
    }
    if ('id' in values && ((modelName === 'FSItem' || modelName === 'Field') || Item.isUsed(values.id))) {
      return modelClass.findCached([values.id], function(err, models) {
        var args, idx, key, name, prop, set, unset, value, _i, _j, _len, _len1;
        if ((err != null) || models.length === 0) {
          return callback("Unexisting " + modelName + " with id " + values.id + ": " + err, modelName);
        }
        model = models[0];
        for (key in values) {
          value = values[key];
          if (key !== 'id' && key !== 'properties') {
            model[key] = value;
          }
          if (key === 'properties') {
            unset = _(model.properties).keys();
            set = [];
            for (name in value) {
              prop = value[name];
              idx = unset.indexOf(name);
              if (-1 === idx) {
                set.push([name, prop.type, prop.def]);
              } else {
                unset.splice(idx, 1);
                if (model.properties[name].type !== prop.type || model.properties[name].def !== prop.def) {
                  set.push([name, prop.type, prop.def]);
                }
              }
            }
            for (_i = 0, _len = set.length; _i < _len; _i++) {
              args = set[_i];
              model.setProperty.apply(model, args);
            }
            for (_j = 0, _len1 = unset.length; _j < _len1; _j++) {
              name = unset[_j];
              model.unsetProperty(name);
            }
          }
        }
        return _save(model);
      });
    } else {
      return _save(new modelClass(values));
    }
  };

  _AdminService.prototype.remove = function(modelName, values, email, callback) {
    var modelClass, removedFields, unqueue;
    if (__indexOf.call(supported, modelName) < 0) {
      return callback("The " + modelName + " model can't be removed", modelName);
    }
    if (!('Field' === modelName || 'FSItem' === modelName || 'id' in values)) {
      return callback("Cannot remove " + modelName + " because no 'id' specified", modelName);
    }
    modelClass = null;
    switch (modelName) {
      case 'ClientConf':
        modelClass = ClientConf;
        break;
      case 'ItemType':
        modelClass = ItemType;
        break;
      case 'EventType':
        modelClass = EventType;
        break;
      case 'FieldType':
        modelClass = FieldType;
        break;
      case 'Executable':
        modelClass = Executable;
        break;
      case 'Map':
        modelClass = Map;
        break;
      case 'Item':
        modelClass = Item;
        break;
      case 'Event':
        modelClass = Event;
        break;
      case 'Player':
        modelClass = Player;
        break;
      case 'Field':
        if (!Array.isArray(values)) {
          return callback('Fields must be removed within an array', modelName);
        }
        removedFields = [];
        unqueue = function(err) {
          var field;
          if (values.length === 0) {
            return callback(err, modelName, removedFields);
          }
          field = values.pop();
          return Field.findById(field.id, function(err, model) {
            if ((err != null) || !(model != null)) {
              return callback("Unexisting field with id " + field.id, modelName, removedFields);
            }
            removedFields.push(model);
            return model.remove(unqueue);
          });
        };
        return unqueue(null);
      case 'FSItem':
        return authoringService.remove(values, email, function(err, removed) {
          return callback(err, modelName, removed);
        });
    }
    return modelClass.findCached([values.id], function(err, models) {
      if ((err != null) || models.length === 0) {
        return callback("Unexisting " + modelName + " with id " + values.id, modelName);
      }
      if (modelName === 'Player') {
        return playerService.disconnect(models[0].email, 'removal', function(err) {
          if (err != null) {
            return callback(err, modelName);
          }
          return models[0].remove(function(err) {
            return callback(err, modelName, Player.purge(models[0]));
          });
        });
      } else {
        return models[0].remove(function(err) {
          return callback(err, modelName, models[0]);
        });
      }
    });
  };

  return _AdminService;

})();

_instance = void 0;

AdminService = (function() {
  function AdminService() {}

  AdminService.get = function() {
    return _instance != null ? _instance : _instance = new _AdminService();
  };

  return AdminService;

})();

module.exports = AdminService;
