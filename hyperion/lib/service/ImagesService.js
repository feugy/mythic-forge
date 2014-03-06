
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
var EventType, FieldType, ImagesService, ItemType, confKey, fs, imagesPath, join, logger, normalize, resolve, supported, _, _ImagesService, _instance, _ref,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __slice = [].slice,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

_ = require('underscore');

fs = require('fs-extra');

_ref = require('path'), join = _ref.join, normalize = _ref.normalize, resolve = _ref.resolve;

confKey = require('../util/common').confKey;

ItemType = require('../model/ItemType');

FieldType = require('../model/FieldType');

EventType = require('../model/EventType');

logger = require('../util/logger').getLogger('service');

imagesPath = resolve(normalize(confKey('images.store')));

supported = ['ItemType', 'FieldType', 'EventType'];

_ImagesService = (function() {
  function _ImagesService() {
    this.removeImage = __bind(this.removeImage, this);
    this.uploadImage = __bind(this.uploadImage, this);
  }

  _ImagesService.prototype.uploadImage = function() {
    var args, callback, ext, id, imageData, modelClass, modelName, suffix;
    modelName = arguments[0], id = arguments[1], ext = arguments[2], imageData = arguments[3], args = 5 <= arguments.length ? __slice.call(arguments, 4) : [];
    switch (args.length) {
      case 1:
        callback = args[0];
        suffix = 'type';
        break;
      case 2:
        callback = args[1];
        suffix = args[0];
    }
    if (__indexOf.call(supported, modelName) < 0) {
      return callback("No image can be uploaded for " + modelName);
    }
    modelClass = null;
    switch (modelName) {
      case 'ItemType':
        modelClass = ItemType;
        break;
      case 'FieldType':
        modelClass = FieldType;
        break;
      case 'EventType':
        modelClass = EventType;
    }
    return modelClass.findCached([id], function(err, models) {
      var existing, model, proceed, _ref1;
      if ((err != null) || models.length === 0) {
        return callback("Unexisting " + modelName + " with id " + id + ": " + err);
      }
      model = models[0];
      switch (args.length) {
        case 1:
          existing = model.descImage;
          break;
        case 2:
          if (!(_.isNumber(suffix) && suffix >= 0)) {
            return callback("idx argument " + suffix + " isn't a positive number");
          }
          existing = (_ref1 = model.images[suffix]) != null ? _ref1.file : void 0;
          break;
        default:
          throw new Error("save must be called with arguments (modelName, id, ext, imageData, [idx], callback)");
      }
      proceed = (function(_this) {
        return function(err) {
          var fileName;
          if ((err != null) && err.code !== 'ENOENT') {
            return callback("Failed to save image " + suffix + " on model " + model.id + ": " + err);
          }
          fileName = "" + model.id + "-" + suffix + "." + ext;
          return fs.writeFile(join(imagesPath, fileName), new Buffer(imageData, 'base64'), function(err) {
            var images, previous;
            if (err != null) {
              return callback("Failed to save image " + suffix + " on model " + model.id + ": " + err);
            }
            if (suffix === 'type') {
              model.descImage = fileName;
            } else {
              images = model.images;
              if (modelName === 'ItemType') {
                previous = images[suffix] || {
                  width: 0,
                  height: 0
                };
                previous.file = fileName;
                images[suffix] = previous;
              } else {
                images[suffix] = fileName;
              }
              model.images = images;
              model.markModified('images');
            }
            return model.save(function(err, saved) {
              if (err != null) {
                fs.unlink(join(imagesPath, fileName));
                return callback("Failed to save image " + suffix + " on model " + model.id + ": " + err);
              }
              return callback(null, saved);
            });
          });
        };
      })(this);
      if (existing) {
        return fs.unlink(join(imagesPath, existing), proceed);
      } else {
        return proceed();
      }
    });
  };

  _ImagesService.prototype.removeImage = function() {
    var args, callback, id, modelClass, modelName, suffix;
    modelName = arguments[0], id = arguments[1], args = 3 <= arguments.length ? __slice.call(arguments, 2) : [];
    switch (args.length) {
      case 1:
        callback = args[0];
        suffix = 'type';
        break;
      case 2:
        callback = args[1];
        suffix = args[0];
    }
    if (__indexOf.call(supported, modelName) < 0) {
      return callback("No image can be uploaded for " + modelName);
    }
    modelClass = null;
    switch (modelName) {
      case 'ItemType':
        modelClass = ItemType;
        break;
      case 'FieldType':
        modelClass = FieldType;
        break;
      case 'EventType':
        modelClass = EventType;
    }
    return modelClass.findCached([id], function(err, models) {
      var existing, model, _ref1;
      if ((err != null) || models.length === 0) {
        return callback("Unexisting " + modelName + " with id " + id + ": " + err);
      }
      model = models[0];
      switch (args.length) {
        case 1:
          existing = model.descImage;
          break;
        case 2:
          if (!(_.isNumber(suffix) && suffix >= 0)) {
            return callback("idx argument " + suffix + " isn't a positive number");
          }
          existing = (_ref1 = model.images[suffix]) != null ? _ref1.file : void 0;
          break;
        default:
          throw new Error("semove must be called with arguments (model, [idx], callback)");
      }
      return fs.unlink(join(imagesPath, existing), (function(_this) {
        return function(err) {
          var images;
          if ((err != null) && err.code !== 'ENOENT') {
            return callback("Failed to remove image " + suffix + " on model " + model.id + ": " + err);
          }
          if (args.length === 1) {
            model.descImage = null;
          } else {
            images = model.images;
            if (suffix === images.length - 1) {
              images.splice(suffix, 1);
            } else {
              if (modelName === 'ItemType') {
                images[suffix].file = null;
              } else {
                images[suffix] = null;
              }
            }
            model.images = images;
            model.markModified('images');
          }
          return model.save(function(err, saved) {
            if (err != null) {
              return callback("Failed to remove image " + suffix + " on model " + model.id + ": " + err);
            }
            return callback(null, saved);
          });
        };
      })(this));
    });
  };

  return _ImagesService;

})();

_instance = void 0;

ImagesService = (function() {
  function ImagesService() {}

  ImagesService.get = function() {
    return _instance != null ? _instance : _instance = new _ImagesService();
  };

  return ImagesService;

})();

module.exports = ImagesService;
