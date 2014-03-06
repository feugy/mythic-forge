
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
var DeployementService, async, coffee, compileCoffee, compileStylus, fs, listVersions, logger, makeCacheable, notifier, optimize, pathUtils, repo, requirejs, root, stylus, utils, versionUtils, _, _DeployementService, _instance,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

_ = require('underscore');

pathUtils = require('path');

coffee = require('coffee-script');

stylus = require('stylus');

fs = require('fs-extra');

async = require('async');

requirejs = require('requirejs');

utils = require('../util/common');

versionUtils = require('../util/versionning');

logger = require('../util/logger').getLogger('service');

notifier = require('../service/Notifier').get();

repo = null;

root = null;

_instance = void 0;

module.exports = DeployementService = (function() {
  function DeployementService() {}

  DeployementService.get = function() {
    return _instance != null ? _instance : _instance = new _DeployementService();
  };

  return DeployementService;

})();

_DeployementService = (function() {
  _DeployementService._deployed = null;

  _DeployementService._deployPending = false;

  _DeployementService._deployer = null;

  function _DeployementService() {
    this.restoreVersion = __bind(this.restoreVersion, this);
    this.createVersion = __bind(this.createVersion, this);
    this.deployementState = __bind(this.deployementState, this);
    this.rollback = __bind(this.rollback, this);
    this.commit = __bind(this.commit, this);
    this.deploy = __bind(this.deploy, this);
    this.deployedVersion = __bind(this.deployedVersion, this);
    this.init = __bind(this.init, this);
    this._deployed = null;
    this.init((function(_this) {
      return function(err) {
        if (err != null) {
          throw new Error("Failed to init: " + err);
        }
      };
    })(this));
  }

  _DeployementService.prototype.init = function(callback) {
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

  _DeployementService.prototype.deployedVersion = function() {
    if (this._deployed != null) {
      return "" + this._deployed;
    } else {
      return null;
    }
  };

  _DeployementService.prototype.deploy = function(version, email, callback) {
    if (this._deployed != null) {
      return callback("Deployment of version " + this._deployed + " already in progress");
    }
    if (this._deployPending) {
      return callback("Commit or rollback of previous version not finished");
    }
    return listVersions((function(_this) {
      return function(err, versions) {
        var error, folder, production, save;
        if (err != null) {
          return callback(err);
        }
        if (__indexOf.call(versions, version) >= 0) {
          return callback("Version " + version + " already used");
        }
        _this._deployPending = true;
        _this._deployed = "" + version;
        _this._deployer = email;
        error = function(err) {
          notifier.notify('deployement', 'DEPLOY_FAILED', err);
          _this._deployed = null;
          _this._deployer = null;
          _this._deployPending = false;
          return callback(err);
        };
        folder = pathUtils.resolve(pathUtils.normalize(utils.confKey('game.client.optimized')));
        production = pathUtils.resolve(pathUtils.normalize(utils.confKey('game.client.production')));
        save = pathUtils.resolve(pathUtils.normalize(utils.confKey('game.client.save')));
        notifier.notify('deployement', 'DEPLOY_START', 1, _this._deployed, _this._deployer);
        return fs.remove(folder, function(err) {
          return fs.remove("" + folder + ".out", function(err) {
            if (err != null) {
              return error("Failed to clean optimized folder: " + err);
            }
            return fs.mkdirs(folder, function(err) {
              if (typeof eff !== "undefined" && eff !== null) {
                return error("Failed to create optimized folder: " + err);
              }
              logger.debug("optimized folder " + folder + " cleaned");
              return fs.copy(root, folder, function(err) {
                var _compileCoffee, _optimize;
                if (err != null) {
                  return error("Failed to copy to optimized folder: " + err);
                }
                logger.debug("client copied to optimized folder");
                _optimize = function() {
                  notifier.notify('deployement', 'OPTIMIZE_JS', 4);
                  return optimize(folder, function(err, root, temp) {
                    if (err != null) {
                      return error("Failed to optimized client: " + err);
                    }
                    notifier.notify('deployement', 'OPTIMIZE_HTML', 5);
                    return makeCacheable(temp, root, _this._deployed, function(err, result) {
                      if (err != null) {
                        return error("Failed to make client cacheable: " + err);
                      }
                      notifier.notify('deployement', 'DEPLOY_FILES', 6);
                      return fs.remove(save, function(err) {
                        if ((err != null) && err.code !== 'ENOENT') {
                          return error("Failed to clean save folder: " + err);
                        }
                        return fs.mkdir(save, function(err) {
                          if (err != null) {
                            return error("Failed to create save folder: " + err);
                          }
                          return fs.copy(production, save, function(err) {
                            if ((err != null) && err.code !== 'ENOENT') {
                              return error("Failed to save current production: " + err);
                            }
                            logger.debug("old version saved");
                            return fs.remove(production, function(err) {
                              if ((err != null) && err.code !== 'ENOENT') {
                                return error("Failed to clean production folder: " + err);
                              }
                              return fs.copy(result, production, function(err) {
                                if (err != null) {
                                  return error("Failed to copy into production folder: " + err);
                                }
                                logger.debug("client moved to production folder");
                                return async.forEach([folder, temp, result], fs.remove, function(err) {
                                  notifier.notify('deployement', 'DEPLOY_END', 7);
                                  _this._deployPending = false;
                                  return callback(null);
                                });
                              });
                            });
                          });
                        });
                      });
                    });
                  });
                };
                _compileCoffee = function() {
                  notifier.notify('deployement', 'COMPILE_COFFEE', 3);
                  return utils.find(folder, /^.*\.coffee?$/, function(err, results) {
                    if ((err != null) || results.length === 0) {
                      return _optimize();
                    }
                    return async.forEach(results, function(script, next) {
                      return compileCoffee(script, next);
                    }, function(err) {
                      if (err != null) {
                        return error("Failed to compile coffee scripts: " + err);
                      }
                      return _optimize();
                    });
                  });
                };
                notifier.notify('deployement', 'COMPILE_STYLUS', 2);
                return utils.find(folder, /^.*\.styl(us)?$/, function(err, results) {
                  if ((err != null) || results.length === 0) {
                    return _compileCoffee();
                  }
                  return async.forEach(results, function(sheet, next) {
                    return compileStylus(sheet, next);
                  }, function(err) {
                    if (err != null) {
                      return error("Failed to compile stylus sheets: " + err);
                    }
                    return _compileCoffee();
                  });
                });
              });
            });
          });
        });
      };
    })(this));
  };

  _DeployementService.prototype.commit = function(email, callback) {
    var error, save;
    if (this._deployed == null) {
      return callback('Commit can only be performed after deploy');
    }
    if (this._deployer !== email) {
      return callback("Commit can only be performed be deployement author " + this._deployer);
    }
    if (this._deployPending) {
      return callback('Deploy not finished');
    }
    this._deployPending = true;
    error = (function(_this) {
      return function(err) {
        notifier.notify('deployement', 'COMMIT_FAILED', err);
        return callback(err);
      };
    })(this);
    save = pathUtils.resolve(pathUtils.normalize(utils.confKey('game.client.save')));
    notifier.notify('deployement', 'COMMIT_START', 1);
    return this.createVersion(this._deployed, this._deployer, 2, (function(_this) {
      return function(err) {
        if (err != null) {
          return error("Failed to create version: " + err);
        }
        return fs.remove(save, function(err) {
          if ((err != null) && err.code !== 'ENOENT') {
            return error("Failed to remove previous version save: " + err);
          }
          logger.debug("previous game client files deleted");
          _this._deployed = null;
          _this._deployer = null;
          _this._deployPending = false;
          notifier.notify('deployement', 'COMMIT_END', 3);
          return callback(null);
        });
      };
    })(this));
  };

  _DeployementService.prototype.rollback = function(email, callback) {
    var error, production, save;
    if (this._deployed == null) {
      return callback('Rollback can only be performed after deploy');
    }
    if (this._deployer !== email) {
      return callback("Rollback can only be performed be deployement author " + this._deployer);
    }
    if (this._deployPending) {
      return callback('Deploy not finished');
    }
    this._deployPending = true;
    save = pathUtils.resolve(pathUtils.normalize(utils.confKey('game.client.save')));
    production = pathUtils.resolve(pathUtils.normalize(utils.confKey('game.client.production')));
    error = (function(_this) {
      return function(err) {
        notifier.notify('deployement', 'ROLLBACK_FAILED', err);
        return callback(err);
      };
    })(this);
    notifier.notify('deployement', 'ROLLBACK_START', 1);
    return fs.remove(production, (function(_this) {
      return function(err) {
        if ((err != null) && err.code !== 'ENOENT') {
          return error("Failed to remove deployed version: " + err);
        }
        logger.debug("deployed game client files deleted");
        return fs.rename(save, production, function(err) {
          if (err != null) {
            return error("Failed to move saved version to production: " + err);
          }
          logger.debug("previous game client files restored");
          _this._deployed = null;
          _this._deployer = null;
          _this._deployPending = false;
          notifier.notify('deployement', 'ROLLBACK_END', 2);
          return callback(null);
        });
      };
    })(this));
  };

  _DeployementService.prototype.deployementState = function(callback) {
    return versionUtils.quickTags(repo, (function(_this) {
      return function(err, tags) {
        var tagIds;
        if (err != null) {
          return callback("Failed to consult versions: " + err);
        }
        tags.reverse();
        tagIds = _.pluck(tags, 'id');
        return versionUtils.quickHistory(repo, function(err, history) {
          var commit, i, id, result, _i, _j, _len, _len1;
          if (err != null) {
            return callback("Failed to consult history: " + err);
          }
          result = {
            deployed: _this._deployed,
            inProgress: _this._deployPending,
            author: _this._deployer,
            current: null,
            versions: _.pluck(tags, 'name')
          };
          for (_i = 0, _len = history.length; _i < _len; _i++) {
            commit = history[_i];
            for (i = _j = 0, _len1 = tagIds.length; _j < _len1; i = ++_j) {
              id = tagIds[i];
              if (!(id === commit.id)) {
                continue;
              }
              result.current = tags[i].name;
              return callback(null, result);
            }
          }
          return callback(null, result);
        });
      };
    })(this));
  };

  _DeployementService.prototype.createVersion = function(version, email, notifNumber, callback) {
    if (_.isFunction(notifNumber)) {
      callback = notifNumber;
      notifNumber = 1;
    }
    if (-1 !== version.indexOf(' ')) {
      return callback('Spaces not allowed in version names');
    }
    return listVersions((function(_this) {
      return function(err, versions) {
        if (err != null) {
          return callback(err);
        }
        if (__indexOf.call(versions, version) >= 0) {
          return callback("Cannot reuse existing version " + version);
        }
        return require('./PlayerService').get().getByEmail(email, function(err, author) {
          var dev, rules;
          if (err != null) {
            return callback("Failed to get author: " + err);
          }
          if (author == null) {
            return callback("No author with email " + email);
          }
          dev = pathUtils.resolve(pathUtils.normalize(utils.confKey('game.client.dev')));
          rules = pathUtils.resolve(pathUtils.normalize(utils.confKey('game.executable.source')));
          return repo.add([dev, rules], {
            'ignore-errors': true,
            A: true
          }, function(err) {
            if (err != null) {
              return callback("Failed to add files to version: " + err);
            }
            return repo.commit(version, {
              author: versionUtils.getAuthor(author)
            }, (function(_this) {
              return function(err, stdout) {
                if ((err != null ? err.code : void 0) === 1 && -1 !== ("" + err).indexOf('warning:')) {
                  err = null;
                }
                if (err != null) {
                  return callback("Failed to commit: " + (utils.purgeFolder(err, root)) + " " + (utils.purgeFolder(stdout, root)));
                }
                return repo.create_tag(version, function(err) {
                  if (err != null) {
                    return callback("Failed to create version: " + err);
                  }
                  notifier.notify('deployement', 'VERSION_CREATED', notifNumber, version);
                  return callback(null);
                });
              };
            })(this));
          });
        });
      };
    })(this));
  };

  _DeployementService.prototype.restoreVersion = function(version, callback) {
    if (this._deployed != null) {
      return callback("Deployment of version " + this._deployed + " in progress");
    }
    return listVersions((function(_this) {
      return function(err, versions) {
        if (err != null) {
          return callback(err);
        }
        if (__indexOf.call(versions, version) < 0) {
          return callback("Unknown version " + version);
        }
        logger.debug("reset working copy to version " + version);
        return repo.git('reset', {
          hard: true
        }, [version], function(err, stdout, stderr) {
          if (err != null) {
            return callback("Failed to restore version " + version + ": " + err);
          }
          notifier.notify('deployement', 'VERSION_RESTORED', 1, version);
          return callback(null);
        });
      };
    })(this));
  };

  return _DeployementService;

})();

listVersions = function(callback) {
  return versionUtils.quickTags(repo, function(err, tags) {
    if (err != null) {
      return callback("Failed to list existing versions: " + err);
    }
    return callback(null, _.pluck(tags, 'name'));
  });
};

compileStylus = function(sheet, callback) {
  var destination, name, parent;
  parent = pathUtils.dirname(sheet);
  name = pathUtils.basename(sheet);
  destination = pathUtils.join(parent, name.replace(/\.styl(us)?$/i, '.css'));
  logger.debug("compiles stylus sheet " + sheet + " with parent " + parent);
  return fs.readFile(sheet, (function(_this) {
    return function(err, content) {
      if (err != null) {
        return callback("failed to read content for " + sheet + ": " + err);
      }
      return stylus(content.toString()).set('compress', 'true').set('paths', [parent]).render(function(err, css) {
        if (err != null) {
          return callback("" + sheet + ": " + err);
        }
        return fs.writeFile(destination, css, (function(_this) {
          return function(err) {
            if (err != null) {
              return callback("failed to write " + destination + ": " + err);
            }
            return fs.remove(sheet, function(err) {
              if (err != null) {
                return callback("failed to delete " + sheet + ": " + err);
              }
              return callback(null);
            });
          };
        })(this));
      });
    };
  })(this));
};

compileCoffee = function(script, callback) {
  var destination;
  destination = script.replace(/\.coffee?$/i, '.js');
  logger.debug("compiles coffee script " + script);
  return fs.readFile(script, (function(_this) {
    return function(err, content) {
      var exc, js;
      if (err != null) {
        return callback("failed to read content for " + script + ": " + err);
      }
      try {
        js = coffee.compile(content.toString(), {
          bare: false
        });
        return fs.writeFile(destination, js, function(err) {
          if (err != null) {
            return callback("failed to write " + destination + ": " + err);
          }
          return fs.remove(script, function(err) {
            if (err != null) {
              return callback("failed to delete " + script + ": " + err);
            }
            return callback(null);
          });
        });
      } catch (_error) {
        exc = _error;
        return callback("" + script + ": " + exc);
      }
    };
  })(this));
};

optimize = function(folder, callback) {
  var folderOut, requireMatcher;
  folderOut = "" + folder + ".out";
  requireMatcher = /<script[^>]*data-main\s*=\s*(["'])(.*)(?=\1)/i;
  return utils.find(folder, /^.*\.html$/i, requireMatcher, function(err, results) {
    var main;
    if (err != null) {
      return callback("failed to identify html page including requirejs: " + err);
    }
    if (results.length === 0) {
      return callback('no html page including requirej found');
    }
    main = _.min(results, function(path) {
      return path.length;
    });
    return fs.readFile(main, function(err, content) {
      var baseUrl, extract, idx, mainFile;
      extract = content.toString().match(requireMatcher);
      mainFile = extract != null ? extract[2] : void 0;
      idx = mainFile.indexOf('"');
      if (idx === -1) {
        idx = mainFile.indexOf("'");
      }
      if (idx !== -1) {
        mainFile = mainFile.slice(0, idx);
      }
      idx = mainFile.lastIndexOf('/');
      if (idx !== -1) {
        mainFile = mainFile.substring(idx + 1);
        baseUrl = './' + (extract != null ? extract[2].substring(0, idx) : void 0);
      } else {
        baseUrl = './';
      }
      logger.debug("found main requirejs file " + mainFile + " in base url " + baseUrl);
      return utils.find(folder, /^.*\.js$/, /requirejs\.config/i, function(err, results) {
        var config, configFile, start;
        if (err != null) {
          return callback("failed to identify requirejs configuration file: " + err);
        }
        if (results.length === 0) {
          return callback('no requirejs configuration file found');
        }
        configFile = _.min(results, function(path) {
          return path.length;
        });
        logger.debug("use requirejs configuration file " + configFile);
        config = {
          appDir: folder,
          dir: folderOut,
          baseUrl: baseUrl,
          mainConfigFile: configFile,
          optimizeCss: 'standard',
          preserveLicenseComments: false,
          locale: null,
          optimize: 'uglify2',
          useStrict: true,
          modules: [
            {
              name: mainFile
            }
          ]
        };
        start = new Date().getTime();
        logger.debug("start optimization...");
        return requirejs.optimize(config, function(result) {
          if (utils.isA(result, Error)) {
            return callback(result.message);
          }
          logger.debug("optimization succeeded in " + ((new Date().getTime() - start) / 1000) + "s");
          logger.debug(result);
          return callback(null, main, folderOut);
        }, function(err) {
          return callback(err.message);
        });
      });
    });
  });
};

makeCacheable = function(folder, main, version, callback) {
  var dest;
  dest = "" + folder + ".tmp";
  return fs.remove(dest, function(err) {
    var timestamp, timestamped;
    if (err != null) {
      return callback("failed to clean temporary folder: " + err);
    }
    timestamp = "" + (new Date().getTime());
    timestamped = pathUtils.join(dest, timestamp);
    return fs.mkdirs(timestamped, function(err) {
      if (err != null) {
        return callback("failed to create timestamped folder: " + err);
      }
      logger.debug("copy inside " + timestamped);
      return fs.copy(folder, timestamped, function(err) {
        if (err != null) {
          return callback("failed to copy to timestamped folder: " + err);
        }
        return async.forEach(['build.txt', pathUtils.basename(main)], function(file, next) {
          return fs.remove(pathUtils.join(timestamped, file), next);
        }, function(err) {
          var newMain;
          if (err != null) {
            return callback("failed to remove none-cached files: " + err);
          }
          newMain = pathUtils.join(dest, pathUtils.basename(main));
          logger.debug("copy main file " + newMain);
          return fs.copy(main, newMain, function(err) {
            if (err != null) {
              return callback("failed to copy new main file: " + err);
            }
            return fs.readFile(newMain, function(err, content) {
              var spec, specs, _i, _len;
              if (err != null) {
                return callback("failed to read new main file: " + err);
              }
              content = content.toString();
              logger.debug("replace links inside " + newMain);
              specs = [
                {
                  pattern: /<\s*script([^>]*)data-main\s*=\s*(["'])(.*(?=\2))\2([^>]*)src\s*=\s*(["'])(.*(?=\5))\5/gi,
                  replace: "<script$1data-main=\"" + timestamp + "/$3\"$4src=\"" + timestamp + "/$6\""
                }, {
                  pattern: /<\s*script([^>]*)src\s*=\s*(["'])(.*(?=\2))\2([^>]*)data-main\s*=\s*(["'])(.*(?=\5))\5/gi,
                  replace: "<script$1src=\"" + timestamp + "/$3\"$4data-main=\"" + timestamp + "/$6\""
                }, {
                  pattern: /<\s*link([^>]*)href\s*=\s*(["'])(.*(?=\2))\2/gi,
                  replace: "<link$1href=\"" + timestamp + "/$3\""
                }, {
                  pattern: /\{\{version\}\}/g,
                  replace: version
                }
              ];
              for (_i = 0, _len = specs.length; _i < _len; _i++) {
                spec = specs[_i];
                content = content.replace(spec.pattern, spec.replace);
              }
              return fs.writeFile(newMain, content, function(err) {
                if (err != null) {
                  return callback("failed to write new main file: " + err);
                }
                logger.debug("" + newMain + " rewritten");
                return callback(null, dest);
              });
            });
          });
        });
      });
    });
  });
};
