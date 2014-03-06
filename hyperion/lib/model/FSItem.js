
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
var FSItem, async, fs, logger, modelWatcher, pathUtils, utils, wasNew, _,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __slice = [].slice;

_ = require('underscore');

pathUtils = require('path');

fs = require('fs-extra');

async = require('async');

utils = require('../util/common');

modelWatcher = require('./ModelWatcher').get();

logger = require('../util/logger').getLogger('model');

wasNew = {};

FSItem = (function() {
  FSItem.prototype.path = '';

  FSItem.prototype.isFolder = false;

  FSItem.prototype.content = null;

  function FSItem() {
    var args, attr, raw, value;
    args = 1 <= arguments.length ? __slice.call(arguments, 0) : [];
    this.equals = __bind(this.equals, this);
    this.move = __bind(this.move, this);
    this.remove = __bind(this.remove, this);
    this.save = __bind(this.save, this);
    switch (args.length) {
      case 1:
        raw = args[0];
        if ('object' !== utils.type(raw)) {
          throw 'FSItem may be constructed from JSON object';
        }
        for (attr in raw) {
          value = raw[attr];
          if (attr === 'path' || attr === 'content' || attr === 'isFolder') {
            this[attr] = value;
          }
        }
        break;
      case 2:
        this.path = args[0];
        this.isFolder = args[1];
        break;
      default:
        throw 'Can only construct FSItem with arguments `raw` or `path`and `isFolder`';
    }
    this.path = pathUtils.normalize(this.path);
    if (Buffer.isBuffer(this.content)) {
      this.content = this.content.toString('base64');
    }
  }

  FSItem.prototype.read = function(callback) {
    return fs.stat(this.path, (function(_this) {
      return function(err, stat) {
        if ((err != null ? err.code : void 0) === 'ENOENT') {
          return callback("Unexisting item " + _this.path + " cannot be read");
        }
        if (err != null) {
          return callback("Cannot read item: " + err);
        }
        if (_this.isFolder !== stat.isDirectory()) {
          return callback("Incompatible folder status (" + _this.isFolder + " for " + _this.path);
        }
        if (_this.isFolder) {
          return fs.readdir(_this.path, function(err, items) {
            if (err != null) {
              return callback("Cannot read folder content: " + err);
            }
            _this.content = [];
            return async.forEach(items, function(item, next) {
              var path;
              path = pathUtils.join(_this.path, item);
              return fs.stat(path, function(err, stat) {
                if (err != null) {
                  return next(err);
                }
                _this.content.push(new FSItem(path, stat.isDirectory()));
                return next();
              });
            }, function(err) {
              if (err != null) {
                _this.content = null;
                if (err != null) {
                  return callback("Cannot construct folder content: " + err);
                }
              }
              _this.content = _.sortBy(_this.content, 'path');
              return callback(null, _this);
            });
          });
        } else {
          return fs.readFile(_this.path, function(err, content) {
            if (err != null) {
              return callback("Cannot read file content: " + err);
            }
            _this.content = content.toString('base64');
            return callback(null, _this);
          });
        }
      };
    })(this));
  };

  FSItem.prototype.save = function(callback) {
    return fs.stat(this.path, (function(_this) {
      return function(err, stat) {
        var isNew, parent, saveFile;
        isNew = false;
        if (err != null) {
          if (err.code !== 'ENOENT') {
            return callback("Cannot read item stat: " + err);
          }
          isNew = true;
        }
        if (!isNew && _this.isFolder !== stat.isDirectory()) {
          return callback("Cannot save " + (_this.isFolder ? 'file' : 'folder') + " " + _this.path + " into " + (_this.isFolder ? 'folder' : 'file'));
        }
        if (_this.isFolder) {
          if (isNew) {
            return fs.mkdirs(_this.path, function(err) {
              if (err != null) {
                return callback("Error while creating new folder " + _this.path + ": " + err);
              }
              logger.debug("folder " + _this.path + " successfully created");
              modelWatcher.change('creation', 'FSItem', _this);
              return callback(null, _this, true);
            });
          } else {
            return callback("Cannot save existing folder " + _this.path);
          }
        } else {
          saveFile = function() {
            var exc, saved;
            try {
              saved = '';
              if (Buffer.isBuffer(_this.content)) {
                saved = _this.content;
                _this.content = _this.content.toString('base64');
              } else if ('string' === utils.type(_this.content)) {
                saved = new Buffer(_this.content, 'base64');
              }
              return fs.writeFile(_this.path, saved, function(err) {
                if (err != null) {
                  return callback("Error while saving file " + _this.path + ": " + err);
                }
                logger.debug("file " + _this.path + " successfully saved");
                modelWatcher.change((isNew ? 'creation' : 'update'), 'FSItem', _this, ['content']);
                return callback(null, _this, isNew);
              });
            } catch (_error) {
              exc = _error;
              return callback("Bad file content for file " + _this.path + ": " + exc);
            }
          };
          if (!isNew) {
            return saveFile();
          }
          parent = pathUtils.dirname(_this.path);
          return fs.mkdirs(parent, function(err) {
            if (err != null) {
              return callback("Error while creating new file " + _this.path + ": " + err);
            }
            return saveFile();
          });
        }
      };
    })(this));
  };

  FSItem.prototype.remove = function(callback) {
    return fs.stat(this.path, (function(_this) {
      return function(err, stat) {
        if ((err != null ? err.code : void 0) === 'ENOENT') {
          return callback("Unexisting item " + _this.path + " cannot be removed");
        }
        _this.isFolder = stat.isDirectory();
        if (_this.isFolder) {
          return fs.remove(_this.path, function(err) {
            if (err != null) {
              return callback("Error while removing folder " + _this.path + ": " + err);
            }
            logger.debug("folder " + _this.path + " successfully removed");
            modelWatcher.change('deletion', 'FSItem', _this);
            return callback(null, _this);
          });
        } else {
          return fs.unlink(_this.path, function(err) {
            if (err != null) {
              return callback("Error while removing file " + _this.path + ": " + err);
            }
            logger.debug("file " + _this.path + " successfully removed");
            modelWatcher.change('deletion', 'FSItem', _this);
            return callback(null, _this);
          });
        }
      };
    })(this));
  };

  FSItem.prototype.move = function(newPath, callback) {
    newPath = pathUtils.normalize(newPath);
    return fs.stat(this.path, (function(_this) {
      return function(err, stat) {
        if ((err != null ? err.code : void 0) === 'ENOENT') {
          return callback("Unexisting item " + _this.path + " cannot be moved");
        }
        if (err != null) {
          return callback("Cannot read item stat: " + err);
        }
        if (_this.isFolder !== stat.isDirectory()) {
          return callback("Cannot move " + (_this.isFolder ? 'file' : 'folder') + " " + _this.path + " into " + (_this.isFolder ? 'folder' : 'file'));
        }
        return fs.exists(newPath, function(exists) {
          var parent;
          if (exists) {
            return callback("Cannot move because new path " + newPath + " already exists");
          }
          parent = pathUtils.dirname(newPath);
          return fs.mkdirs(parent, function(err) {
            if (err != null) {
              return callback("Error while creating new item " + _this.path + ": " + err);
            }
            return fs.copy(_this.path, newPath, function(err) {
              if (err != null) {
                return callback("Cannot copy item " + _this.path + " to " + newPath + ": " + err);
              }
              return fs.remove(_this.path, function(err) {
                if (err != null) {
                  return callback("Error while removing olf item " + _this.path + ": " + err);
                }
                logger.debug("item " + _this.path + " successfully moved to " + newPath);
                modelWatcher.change('deletion', 'FSItem', new FSItem(_this.path, _this.isFolder));
                _this.path = newPath;
                modelWatcher.change('creation', 'FSItem', _this);
                return callback(null, _this);
              });
            });
          });
        });
      };
    })(this));
  };

  FSItem.prototype.equals = function(object) {
    return this.path === (object != null ? object.path : void 0);
  };

  return FSItem;

})();

module.exports = FSItem;
