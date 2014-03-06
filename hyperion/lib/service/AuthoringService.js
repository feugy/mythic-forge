
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
var AuthoringService, Executable, FSItem, confKey, deployementService, executablesRoot, extname, join, logger, normalize, notifier, purgeFolder, relative, repo, resolve, root, versionUtils, _, _AuthoringService, _instance, _ref, _ref1,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

_ = require('underscore');

FSItem = require('../model/FSItem');

Executable = require('../model/Executable');

_ref = require('path'), resolve = _ref.resolve, normalize = _ref.normalize, join = _ref.join, relative = _ref.relative, extname = _ref.extname;

_ref1 = require('../util/common'), purgeFolder = _ref1.purgeFolder, confKey = _ref1.confKey;

versionUtils = require('../util/versionning');

logger = require('../util/logger').getLogger('service');

deployementService = require('./DeployementService').get();

notifier = require('../service/Notifier').get();

executablesRoot = resolve(normalize(confKey('game.executable.source')));

repo = null;

root = null;

_instance = void 0;

module.exports = AuthoringService = (function() {
  function AuthoringService() {}

  AuthoringService.get = function() {
    return _instance != null ? _instance : _instance = new _AuthoringService();
  };

  return AuthoringService;

})();

_AuthoringService = (function() {
  function _AuthoringService() {
    this.readVersion = __bind(this.readVersion, this);
    this.restorables = __bind(this.restorables, this);
    this.history = __bind(this.history, this);
    this.read = __bind(this.read, this);
    this.move = __bind(this.move, this);
    this.remove = __bind(this.remove, this);
    this.save = __bind(this.save, this);
    this.readRoot = __bind(this.readRoot, this);
    this.init = __bind(this.init, this);
    this.init((function(_this) {
      return function(err) {
        if (err != null) {
          throw new Error("Failed to init: " + err);
        }
      };
    })(this));
  }

  _AuthoringService.prototype.init = function(callback) {
    return versionUtils.initGameRepo(logger, (function(_this) {
      return function(err, _root, _repo) {
        if (err != null) {
          return callback(err);
        }
        root = _root;
        repo = _repo;
        return callback(null);
      };
    })(this));
  };

  _AuthoringService.prototype.readRoot = function(callback) {
    return new FSItem(root, true).read((function(_this) {
      return function(err, rootFolder) {
        var file, _i, _len, _ref2;
        if (err != null) {
          return callback("Failed to get root content: " + (purgeFolder(err, root)));
        }
        rootFolder.path = '';
        _ref2 = rootFolder.content;
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          file = _ref2[_i];
          file.path = relative(root, file.path);
        }
        return callback(null, rootFolder);
      };
    })(this));
  };

  _AuthoringService.prototype.save = function(item, email, callback) {
    var deployed, exc;
    deployed = deployementService.deployedVersion();
    if (deployed != null) {
      return callback("Deployment of version " + deployed + " in progress");
    }
    try {
      item = new FSItem(item);
    } catch (_error) {
      exc = _error;
      return callback("Only FSItem are supported: " + exc);
    }
    item.path = resolve(root, item.path);
    return item.save((function(_this) {
      return function(err, saved, isNew) {
        if (err != null) {
          return callback(purgeFolder(err, root));
        }
        saved.path = relative(root, saved.path);
        return callback(null, saved);
      };
    })(this));
  };

  _AuthoringService.prototype.remove = function(item, email, callback) {
    var deployed, exc;
    deployed = deployementService.deployedVersion();
    if (deployed != null) {
      return callback("Deployment of version " + deployed + " in progress");
    }
    try {
      item = new FSItem(item);
    } catch (_error) {
      exc = _error;
      return callback("Only FSItem are supported: " + exc);
    }
    item.path = resolve(root, item.path);
    return item.remove((function(_this) {
      return function(err, removed) {
        if (err != null) {
          return callback(purgeFolder(err, root));
        }
        logger.debug("" + removed.path + " removed");
        removed.path = relative(root, removed.path);
        return callback(null, removed);
      };
    })(this));
  };

  _AuthoringService.prototype.move = function(item, newPath, email, callback) {
    var deployed, exc;
    deployed = deployementService.deployedVersion();
    if (deployed != null) {
      return callback("Deployment of version " + deployed + " in progress");
    }
    try {
      item = new FSItem(item);
    } catch (_error) {
      exc = _error;
      return callback("Only FSItem are supported: " + exc);
    }
    item.path = resolve(root, item.path);
    return item.move(resolve(root, newPath), (function(_this) {
      return function(err, moved) {
        if (err != null) {
          return callback(purgeFolder(err, root));
        }
        moved.path = relative(root, moved.path);
        return callback(null, moved);
      };
    })(this));
  };

  _AuthoringService.prototype.read = function(item, callback) {
    var exc;
    try {
      item = new FSItem(item);
    } catch (_error) {
      exc = _error;
      return callback("Only FSItem are supported: " + exc);
    }
    item.path = resolve(root, item.path);
    return item.read((function(_this) {
      return function(err, read) {
        var file, _i, _len, _ref2;
        if (err != null) {
          return callback(purgeFolder(err, root));
        }
        read.path = relative(root, read.path);
        if (read.isFolder) {
          _ref2 = read.content;
          for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
            file = _ref2[_i];
            file.path = relative(root, file.path);
          }
        }
        return callback(null, read);
      };
    })(this));
  };

  _AuthoringService.prototype.history = function(item, callback) {
    var exc, obj, path;
    path = null;
    obj = null;
    if (_.isObject(item) && (item != null ? item.id : void 0)) {
      try {
        obj = new Executable(item);
        path = obj.path;
      } catch (_error) {
        exc = _error;
        return callback("Only Executable and FSItem files are supported: " + exc);
      }
    } else {
      try {
        obj = new FSItem(item);
        path = join(root, obj.path);
      } catch (_error) {
        exc = _error;
        return callback("Only Executable and FSItem files are supported: " + exc);
      }
      if (obj.isFolder) {
        return callback('History not supported on folders');
      }
    }
    return versionUtils.quickHistory(repo, path, (function(_this) {
      return function(err, history) {
        if (err != null) {
          return callback("Failed to get history: " + err);
        }
        return callback(null, obj, history);
      };
    })(this));
  };

  _AuthoringService.prototype.restorables = function(callback) {
    return versionUtils.listRestorables(repo, (function(_this) {
      return function(err, restorables) {
        var exeRoot, ext, fileRoot, obj, restorable, results, _i, _len;
        if (err != null) {
          return callback("Failed to get restorable list: " + err);
        }
        results = [];
        fileRoot = root.replace(repo.path, '').slice(1);
        exeRoot = executablesRoot.replace(repo.path, '').slice(1);
        for (_i = 0, _len = restorables.length; _i < _len; _i++) {
          restorable = restorables[_i];
          if (0 === restorable.path.indexOf(fileRoot)) {
            obj = new FSItem({
              isFolder: false,
              path: restorable.path.slice(fileRoot.length + 1)
            });
          } else {
            ext = extname(restorable.path);
            obj = new Executable({
              id: restorable.path.slice(exeRoot.length + 1).replace(ext, ''),
              lang: ext.slice(1)
            });
          }
          results.push({
            item: obj,
            id: restorable.id
          });
        }
        return callback(err, results);
      };
    })(this));
  };

  _AuthoringService.prototype.readVersion = function(item, version, callback) {
    var exc, obj, path;
    path = null;
    obj = null;
    if (_.isObject(item) && (item != null ? item.id : void 0)) {
      try {
        obj = new Executable(item);
        path = obj.path;
      } catch (_error) {
        exc = _error;
        return callback("Only Executable and FSItem files are supported: " + exc);
      }
    } else {
      try {
        obj = new FSItem(item);
        path = join(root, obj.path);
      } catch (_error) {
        exc = _error;
        return callback("Only Executable and FSItem files are supported: " + exc);
      }
      if (obj.isFolder) {
        return callback('History not supported on folders');
      }
    }
    path = path.replace(repo.path, '').replace(/\\/g, '\/');
    return repo.git('show', {}, "" + version + ":." + path, (function(_this) {
      return function(err, stdout, stderr) {
        if (err != null) {
          return callback("Failed to get version content: " + err);
        }
        return callback(err, obj, new Buffer(stdout, 'binary').toString('base64'));
      };
    })(this));
  };

  return _AuthoringService;

})();
