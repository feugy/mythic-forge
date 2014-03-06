
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
var Executable, MongoClient, async, caches, compareArrayProperty, compareObjProperty, fs, idCache, imageStore, loadIdCache, logger, modelUtils, modelWatcher, mongoose, originalIsModified, original_registerHooks, path, utils, _,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

mongoose = require('mongoose');

_ = require('underscore');

fs = require('fs');

path = require('path');

async = require('async');

MongoClient = require('mongodb').MongoClient;

Executable = require('../model/Executable');

modelWatcher = require('./ModelWatcher').get();

logger = require('../util/logger').getLogger('model');

utils = require('../util/common');

modelUtils = require('../util/model');

imageStore = utils.confKey('images.store');

idCache = {};

caches = {};

loadIdCache = function(callback) {
  var db, host, pass, port, user;
  if (callback == null) {
    callback = null;
  }
  host = utils.confKey('mongo.host', 'localhost');
  port = utils.confKey('mongo.port', 27017);
  db = utils.confKey('mongo.db');
  user = utils.confKey('mongo.user', null);
  pass = utils.confKey('mongo.password', null);
  return MongoClient.connect("mongodb://" + ((user != null) && (pass != null) ? "" + user + ":" + pass + "@" : '') + host + ":" + port + "/" + db, function(err, db) {
    if (err != null) {
      throw new Error("Failed to connect to mongo to get ids: " + err);
    }
    idCache = {};
    return async.forEach(['players', 'items', 'itemtypes', 'events', 'eventtypes', 'maps', 'fieldtypes', 'clientconfs'], function(name, next) {
      return db.collection(name).find({}, {
        fields: {
          _id: 1
        }
      }).toArray(function(err, results) {
        var obj, _i, _len;
        if (err != null) {
          return next(err);
        }
        for (_i = 0, _len = results.length; _i < _len; _i++) {
          obj = results[_i];
          idCache[obj._id] = 1;
        }
        return next();
      });
    }, function(err) {
      if (err != null) {
        throw new Error("Failed to retrieve ids of collection " + name + ": " + err);
      }
      db.close();
      if (callback != null) {
        return callback();
      }
    });
  });
};

modelWatcher.on('change', function(operation, className, changes) {
  if (operation === 'creation') {
    return idCache[changes.id] = 1;
  } else if (operation === 'deletion' && changes.id in idCache) {
    return delete idCache[changes.id];
  }
});

modelWatcher.on('executableReset', function(removed) {
  var id, _i, _len, _results;
  _results = [];
  for (_i = 0, _len = removed.length; _i < _len; _i++) {
    id = removed[_i];
    if (id in idCache) {
      _results.push(delete idCache[id]);
    }
  }
  return _results;
});

loadIdCache();

original_registerHooks = mongoose.Document.prototype.$__registerHooks;

mongoose.Document.prototype.$__registerHooks = function() {
  var ret;
  ret = original_registerHooks.apply(this, arguments);
  this._defineProperties();
  return ret;
};

compareArrayProperty = function(instance, prop) {
  var current, original;
  original = instance["__orig" + prop] || [];
  current = _.map(instance[prop] || [], function(linked) {
    if ('object' === utils.type(linked) && ((linked != null ? linked.id : void 0) != null)) {
      return linked.id;
    } else {
      return linked;
    }
  });
  if (!_.isEqual(original, current)) {
    return instance.markModified(prop);
  }
};

compareObjProperty = function(instance, prop) {
  var current, original;
  original = instance["_orig" + prop] || "{}";
  current = JSON.stringify(instance[prop] || {});
  if (original !== current) {
    return instance.markModified(prop);
  }
};

originalIsModified = mongoose.Document.prototype.isModified;

mongoose.Document.prototype.isModified = function(path) {
  var prop, value, _ref, _ref1;
  if (((_ref = this.type) != null ? _ref.properties : void 0) != null) {
    _ref1 = this.type.properties;
    for (prop in _ref1) {
      value = _ref1[prop];
      if (value.type === 'array') {
        compareArrayProperty(this, prop);
      }
    }
  }
  if (this._className === 'Player') {
    compareArrayProperty(this, 'characters');
    compareObjProperty(this, 'prefs');
  }
  if (this._className === 'ClientConf') {
    compareObjProperty(this, 'values');
  }
  return originalIsModified.apply(this, arguments);
};

mongoose.Document.prototype._defineProperties = function() {
  var name, prop, _ref, _ref1, _results;
  if (((_ref = this.type) != null ? _ref.properties : void 0) != null) {
    _ref1 = this.type.properties;
    _results = [];
    for (name in _ref1) {
      prop = _ref1[name];
      _results.push(((function(_this) {
        return function(name) {
          if (Object.getOwnPropertyDescriptor(_this, name) == null) {
            return Object.defineProperty(_this, name, {
              enumerable: true,
              configurable: true,
              get: function() {
                return this.get(name);
              },
              set: function(v) {
                return this.set(name, v);
              }
            });
          }
        };
      })(this))(name));
    }
    return _results;
  }
};

module.exports = function(typeName, spec, options) {
  var AbstractType, middleware, name, _ref;
  if (options == null) {
    options = {};
  }
  caches[typeName] = {};
  modelWatcher.on('change', function(operation, className, changes, wId) {
    var attr, instance, value, _results;
    wId = wId || process.pid;
    if (!(className === typeName && (caches[typeName][changes != null ? changes.id : void 0] != null))) {
      return;
    }
    switch (operation) {
      case 'update':
        if (wId !== process.pid) {
          _results = [];
          for (attr in changes) {
            value = changes[attr];
            if (!(!(attr === 'id' || attr === '__v'))) {
              continue;
            }
            instance = caches[typeName][changes.id];
            instance._doc[attr] = value;
            if (("__orig" + attr) in instance) {
              if (_.isArray(instance["__orig" + attr])) {
                _results.push(instance["__orig" + attr] = _.map(value || [], function(o) {
                  if ('object' === utils.type(o) && ((o != null ? o.id : void 0) != null)) {
                    return o.id;
                  } else {
                    return o;
                  }
                }));
              } else {
                _results.push(instance["__orig" + attr] = value);
              }
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        }
        break;
      case 'deletion':
        return delete caches[typeName][changes.id];
    }
  });
  spec.versionKey = false;
  if (options.typeProperties) {
    spec.properties = {
      type: {},
      "default": function() {
        return {};
      }
    };
  }
  if (options.instanceProperties) {
    spec.type = {
      type: {},
      required: true
    };
  }
  options.toObject = {
    transform: function(doc, ret, options) {
      if (options != null ? options.json : void 0) {
        ret._className = doc._className;
        if (doc._className === 'Player') {
          ret.prefs = doc.prefs;
        }
      }
      return ret;
    }
  };
  options.toJSON = {
    transform: function(doc, ret, options) {
      ret._className = doc._className;
      if (doc._className === 'Player') {
        ret.prefs = doc.prefs;
      }
      ret.id = ret._id;
      delete ret._id;
      delete ret.__v;
      return ret;
    }
  };
  options._id = false;
  spec._id = String;
  AbstractType = new mongoose.Schema(spec, options);
  AbstractType.virtual('_className').get(function() {
    return typeName;
  });
  AbstractType.virtual('id').set(function(value) {
    return this._id = value;
  });
  AbstractType.methods.equals = function(object) {
    if ('string' !== utils.type(object != null ? object.id : void 0)) {
      return false;
    }
    return this.id === object.id;
  };
  if ('object' === utils.type(options.middlewares)) {
    _ref = options.middlewares;
    for (name in _ref) {
      middleware = _ref[name];
      AbstractType.pre(name, middleware);
    }
  }
  AbstractType.statics.findCached = function(ids, callback) {
    var cached, id, notCached, _i, _len;
    ids = _.uniq(ids) || [];
    notCached = [];
    cached = [];
    for (_i = 0, _len = ids.length; _i < _len; _i++) {
      id = ids[_i];
      if (id in caches[typeName]) {
        cached.push(caches[typeName][id]);
      } else {
        notCached.push(id);
      }
    }
    if (notCached.length === 0) {
      return _.defer(function() {
        return callback(null, cached);
      });
    }
    return this.find({
      _id: {
        $in: notCached
      }
    }, (function(_this) {
      return function(err, results) {
        if (err != null) {
          return callback(err);
        }
        return callback(null, (function() {
          var _j, _len1, _results;
          _results = [];
          for (_j = 0, _len1 = ids.length; _j < _len1; _j++) {
            id = ids[_j];
            if (caches[typeName][id] != null) {
              _results.push(caches[typeName][id]);
            }
          }
          return _results;
        })());
      };
    })(this));
  };
  AbstractType.statics.loadIdCache = function(callback) {
    if (process.env.NODE_ENV !== 'test') {
      throw new Error('Never use it in production!');
    }
    return loadIdCache(callback);
  };
  AbstractType.statics.isUsed = function(id) {
    return id in idCache || Executable.findCached([id]).length !== 0;
  };
  AbstractType.post('init', function() {
    return caches[typeName][this.id] = this;
  });
  AbstractType.post('save', function() {
    return caches[typeName][this.id] = this;
  });
  AbstractType.post('remove', function() {
    var id;
    delete caches[typeName][this.id];
    modelWatcher.change('deletion', typeName, this);
    if (options.hasImages) {
      id = this.id;
      return fs.readdir(imageStore, function(err, files) {
        var file, _i, _len, _results;
        if ((err != null ? err.code : void 0) === 'ENOENT') {
          return;
        }
        _results = [];
        for (_i = 0, _len = files.length; _i < _len; _i++) {
          file = files[_i];
          if (file.indexOf("" + id + "-") === 0) {
            _results.push(fs.unlink(path.join(imageStore, file)));
          }
        }
        return _results;
      });
    }
  });
  if (options.typeProperties) {
    AbstractType.methods.setProperty = function(name, type, def) {
      if (type === 'date' && 'string' === utils.type(def)) {
        def = new Date(def);
      }
      this.properties[name] = {
        type: type,
        def: def
      };
      this.markModified('properties');
      if (this._updatedProps == null) {
        this._updatedProps = [];
      }
      return this._updatedProps.push(name);
    };
    AbstractType.methods.unsetProperty = function(name) {
      if (this.properties[name] == null) {
        throw new Error("Unknown property " + name + " for type " + this.id);
      }
      delete this.properties[name];
      this.markModified('properties');
      if (this._deletedProps == null) {
        this._deletedProps = [];
      }
      return this._deletedProps.push(name);
    };
    AbstractType.pre('save', function(next) {
      if (!((this._updatedProps != null) || (this._deletedProps != null))) {
        return next();
      }
      return require("./" + options.instanceClass).find({
        type: this.id
      }, (function(_this) {
        return function(err, instances) {
          var def, instance, prop, saved, _i, _j, _k, _len, _len1, _len2, _ref1, _ref2;
          if (err != null) {
            return next(new Error("Failed to update type instances: " + err));
          }
          saved = [];
          for (_i = 0, _len = instances.length; _i < _len; _i++) {
            instance = instances[_i];
            if (_this._updatedProps != null) {
              _ref1 = _this._updatedProps;
              for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
                name = _ref1[_j];
                prop = _this.properties[name];
                def = prop.def;
                switch (prop.type) {
                  case 'array':
                    def = [];
                    break;
                  case 'object':
                    def = null;
                }
                err = modelUtils.checkPropertyType(def, prop);
                if (err != null) {
                  return next(new Error(err));
                }
                if (void 0 === instance.get(name)) {
                  instance.set(name, def);
                  if (__indexOf.call(instance, saved) < 0) {
                    saved.push(instance);
                  }
                }
              }
            }
            if (_this._deletedProps != null) {
              _ref2 = _this._deletedProps;
              for (_k = 0, _len2 = _ref2.length; _k < _len2; _k++) {
                name = _ref2[_k];
                instance.set(name, void 0);
                delete instance._doc[name];
                if (__indexOf.call(instance, saved) < 0) {
                  saved.push(instance);
                }
              }
            }
          }
          delete _this._deletedProps;
          delete _this._updatedProps;
          return async.forEach(saved, function(instance, done) {
            return instance.save(done);
          }, next);
        };
      })(this));
    });
  }
  if (options.instanceProperties) {
    AbstractType.pre('init', function(next, instance) {
      return require("./" + options.typeClass).findCached([instance.type], function(err, types) {
        if (err != null) {
          return next(new Error("Unable to init instance " + instance.id + ". Error while resolving its type: " + err));
        }
        if (types.length !== 1) {
          return next(new Error("Unable to init instance " + instance.id + " because there is no type with id " + instance.type));
        }
        instance.type = types[0];
        return next();
      });
    });
    AbstractType.post('init', function() {
      var _ref1, _ref2, _results;
      this._defineProperties();
      _ref1 = this.type.properties;
      _results = [];
      for (name in _ref1) {
        spec = _ref1[name];
        if (spec.type === 'array') {
          _results.push(this["__orig" + name] = ((_ref2 = this[name]) != null ? _ref2.concat() : void 0) || []);
        }
      }
      return _results;
    });
    AbstractType.methods.fetch = function(breakCycles, callback) {
      var _ref1;
      if (_.isFunction(breakCycles)) {
        _ref1 = [breakCycles, false], callback = _ref1[0], breakCycles = _ref1[1];
      }
      return AbstractType.statics.fetch([this], breakCycles, (function(_this) {
        return function(err, instances) {
          return callback(err, (instances != null ? instances[0] : void 0) || null);
        };
      })(this));
    };
    AbstractType.statics.fetch = function(instances, breakCycles, callback) {
      var def, ids, instance, linked, prop, properties, val, value, _i, _j, _len, _len1, _ref1;
      if (_.isFunction(breakCycles)) {
        _ref1 = [breakCycles, false], callback = _ref1[0], breakCycles = _ref1[1];
      }
      ids = [];
      for (_i = 0, _len = instances.length; _i < _len; _i++) {
        instance = instances[_i];
        logger.debug("search linked ids in " + instance.id);
        properties = instance.type.properties;
        for (prop in properties) {
          def = properties[prop];
          value = instance[prop];
          if (def.type === 'object') {
            if (!breakCycles) {
              if (((value != null ? value.id : void 0) != null) || 'string' === utils.type(value)) {
                logger.debug("found " + (value.id || value) + " in property " + prop);
                ids.push(value.id || value);
              }
            } else if ('string' === utils.type(value)) {
              logger.debug("found " + value + " in property " + prop);
              ids.push(value);
            }
          } else if (def.type === 'array' && (value != null ? value.length : void 0) > 0) {
            for (_j = 0, _len1 = value.length; _j < _len1; _j++) {
              val = value[_j];
              if (!breakCycles) {
                if (((val != null ? val.id : void 0) != null) || 'string' === utils.type(val)) {
                  logger.debug("found " + (val.id || val) + " in property " + prop);
                  ids.push(val.id || val);
                }
              } else if ('string' === utils.type(val)) {
                logger.debug("found " + val + " in property " + prop);
                ids.push(val);
              }
            }
          }
        }
      }
      if (!(ids.length > 0)) {
        return callback(null, instances);
      }
      linked = [];
      return async.forEach([
        {
          name: 'Item',
          clazz: require('./Item')
        }, {
          name: 'Event',
          clazz: require('./Event')
        }
      ], function(spec, end) {
        var cachedIds, id;
        cachedIds = breakCycles ? [] : _.intersection(ids, _.keys(caches[spec.name]));
        if (cachedIds.length > 0) {
          linked = linked.concat((function() {
            var _k, _len2, _results;
            _results = [];
            for (_k = 0, _len2 = cachedIds.length; _k < _len2; _k++) {
              id = cachedIds[_k];
              _results.push(caches[spec.name][id]);
            }
            return _results;
          })());
        }
        if (cachedIds.length === ids.length) {
          return end();
        }
        return spec.clazz.find({
          _id: {
            $in: _.difference(ids, cachedIds)
          }
        }, function(err, results) {
          if (err != null) {
            return callback("Unable to resolve linked on " + instances + ". Error while retrieving linked: " + err);
          }
          linked = linked.concat(results);
          return end();
        });
      }, function() {
        var i, l, link, result, _k, _l, _len2, _len3, _len4, _m, _ref2;
        for (_k = 0, _len2 = instances.length; _k < _len2; _k++) {
          instance = instances[_k];
          properties = instance.type.properties;
          logger.debug("replace linked ids in " + instance.id);
          for (prop in properties) {
            def = properties[prop];
            value = instance._doc[prop];
            if (def.type === 'object') {
              link = null;
              for (_l = 0, _len3 = linked.length; _l < _len3; _l++) {
                l = linked[_l];
                if (l.id === ((value != null ? value.id : void 0) || value)) {
                  link = l;
                  break;
                }
              }
              logger.debug("replace with object " + (link != null ? link.id : void 0) + " in property " + prop);
              instance._doc[prop] = link;
            } else if (def.type === 'array' && (value != null ? value.length : void 0) > 0) {
              result = [];
              for (i = _m = 0, _len4 = value.length; _m < _len4; i = ++_m) {
                val = value[i];
                result[i] = _.find(linked, function(link) {
                  return link.id === ((val != null ? val.id : void 0) || val);
                });
                logger.debug("replace with object " + ((_ref2 = result[i]) != null ? _ref2.id : void 0) + " position " + i + " in property " + prop);
              }
              instance._doc[prop] = _.filter(result, function(obj) {
                return obj != null;
              });
              instance["__orig" + prop] = _.map(instance._doc[prop], function(obj) {
                return obj.id;
              });
            }
          }
        }
        return callback(null, instances);
      });
    };
    AbstractType.pre('save', function(next) {
      var attr, attrs, err, modifiedPaths, prop, properties, saveType, value, wasNew, _i, _len, _ref1, _ref2;
      if (this.type == null) {
        return next(new Error("Cannot save instance " + this._className + " (" + this.id + ") without type"));
      }
      properties = this.type.properties;
      attrs = Object.keys(this._doc);
      for (_i = 0, _len = attrs.length; _i < _len; _i++) {
        attr = attrs[_i];
        if (attr !== '__v') {
          if (attr in properties) {
            err = modelUtils.checkPropertyType(this._doc[attr], properties[attr]);
            if (err != null) {
              next(new Error("Unable to save instance " + this.id + ". Property " + attr + ": " + err));
            }
          } else if (!(attr in AbstractType.paths)) {
            next(new Error("Unable to save instance " + this.id + ": unknown property " + attr));
          }
        }
      }
      for (prop in properties) {
        value = properties[prop];
        if (void 0 === this._doc[prop]) {
          this._doc[prop] = value.type === 'array' ? [] : value.type === 'object' ? null : value.def;
        }
        if (value.type === 'date' && 'string' === utils.type(this._doc[prop])) {
          this._doc[prop] = new Date(this._doc[prop]);
        }
      }
      wasNew = this.isNew;
      if (!((this.id != null) || !wasNew)) {
        this.id = modelUtils.generateId();
      }
      if (wasNew) {
        if (!modelUtils.isValidId(this.id)) {
          return next(new Error("id " + this.id + " for model " + typeName + " is invalid"));
        }
        if (this.id in idCache) {
          return next(new Error("id " + this.id + " for model " + typeName + " is already used"));
        }
      } else {
        if (this.isModified('_id')) {
          return next(new Error("id cannot be changed on a " + typeName));
        }
      }
      modifiedPaths = this.modifiedPaths().concat();
      modelUtils.processLinks(this, properties);
      saveType = this.type;
      this._doc.type = saveType != null ? saveType.id : void 0;
      next();
      _ref1 = saveType.properties;
      for (name in _ref1) {
        spec = _ref1[name];
        if (spec.type === 'array') {
          this["__orig" + name] = ((_ref2 = this._doc[name]) != null ? _ref2.concat() : void 0) || [];
        }
      }
      this._doc.type = saveType;
      return modelWatcher.change((wasNew ? 'creation' : 'update'), typeName, this, modifiedPaths);
    });
  } else {
    AbstractType.pre('save', function(next) {
      var modifiedPaths, wasNew;
      wasNew = this.isNew;
      if (!((this.id != null) || !wasNew)) {
        this.id = modelUtils.generateId();
      }
      if (wasNew) {
        if (!modelUtils.isValidId(this.id)) {
          return next(new Error("id " + this.id + " for model " + typeName + " is invalid"));
        }
        if (this.id in idCache) {
          return next(new Error("id " + this.id + " for model " + typeName + " is already used"));
        }
      } else {
        if (this.isModified('_id')) {
          return next(new Error("id cannot be changed on a " + typeName));
        }
      }
      modifiedPaths = this.modifiedPaths().concat();
      next();
      return modelWatcher.change((wasNew ? 'creation' : 'update'), typeName, this, modifiedPaths);
    });
  }
  return AbstractType;
};
