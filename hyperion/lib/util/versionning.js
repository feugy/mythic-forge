
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
var async, confKey, enforceFolderSync, fs, git, join, normalize, quickHistory, quickTags, removeSync, repoInit, resolve, _, _ref, _ref1;

_ = require('underscore');

_ref = require('../util/common'), confKey = _ref.confKey, enforceFolderSync = _ref.enforceFolderSync, removeSync = _ref.removeSync;

fs = require('fs-extra');

async = require('async');

_ref1 = require('path'), join = _ref1.join, resolve = _ref1.resolve, normalize = _ref1.normalize;

git = require('gift');

quickTags = function(repo, callback) {
  return repo.git('show-ref', {
    tags: true
  }, (function(_this) {
    return function(err, stdout, stderr) {
      var idx, line, lines, tags, _i, _len;
      if ((err != null ? err.code : void 0) === 1) {
        err = null;
      }
      if (err != null) {
        return callback("failed to read tags: " + err + " " + stderr);
      }
      tags = [];
      lines = stdout.split('\n');
      for (_i = 0, _len = lines.length; _i < _len; _i++) {
        line = lines[_i];
        idx = line.indexOf(' ');
        if (idx === -1) {
          continue;
        }
        tags.push({
          name: line.substring(idx + 1).replace('refs/tags/', ''),
          id: line.substring(0, idx)
        });
      }
      return callback(null, tags);
    };
  })(this));
};

quickHistory = function(repo, file, callback) {
  var options;
  options = {
    format: 'format:"%H %at %aN|%s"'
  };
  if (callback == null) {
    callback = file;
    file = [];
  } else {
    file = ['--', file];
    options.follow = true;
  }
  return repo.git('log', options, file, (function(_this) {
    return function(err, stdout, stderr) {
      var date, history, line, lines, sep1, sep2, sep3, _i, _len;
      if ((err != null ? err.code : void 0) === 1 || (err != null ? err.code : void 0) === 128) {
        err = null;
      }
      if (err != null) {
        return callback("failed to read history: " + err + " " + stderr);
      }
      history = [];
      lines = stdout.split('\n');
      for (_i = 0, _len = lines.length; _i < _len; _i++) {
        line = lines[_i];
        sep1 = line.indexOf(' ');
        sep2 = line.indexOf(' ', sep1 + 1);
        sep3 = line.indexOf('|', sep2 + 1);
        if (!(sep1 !== -1 && sep2 !== -1 && sep3 !== -1)) {
          continue;
        }
        date = new Date();
        date.setTime(Number("" + (line.substring(sep1 + 1, sep2)) + "000"));
        history.push({
          id: line.substring(0, sep1),
          date: date,
          author: line.substring(sep2 + 1, sep3),
          message: line.substring(sep3 + 1)
        });
      }
      return callback(null, history);
    };
  })(this));
};

repoInit = false;

module.exports = {
  getAuthor: function(player) {
    var email, firstName, lastName;
    firstName = player.firstName || '';
    lastName = player.lastName || '';
    if (!(lastName || firstName)) {
      lastName = player.email;
    }
    email = player.email;
    if (-1 === email.indexOf('@')) {
      email += '@unknown.org';
    }
    return "" + firstName + " " + lastName + " <" + email + ">";
  },
  initGameRepo: function(logger, reset, callback) {
    var err, executables, finished, imagesPath, repository, root, _ref2;
    if (_.isFunction(reset)) {
      _ref2 = [reset, false], callback = _ref2[0], reset = _ref2[1];
    }
    if (repoInit) {
      return _.delay(function() {
        return module.exports.initGameRepo(logger, reset, callback);
      }, 250);
    }
    root = resolve(normalize(confKey('game.client.dev')));
    repository = resolve(normalize(confKey('game.repo')));
    if (0 !== root.indexOf(repository)) {
      throw new Error("game.client.dev must not be inside game.repo");
    }
    executables = resolve(normalize(confKey('game.executable.source')));
    if (0 !== executables.indexOf(repository)) {
      throw new Error("game.executable.source must not be inside game.repo");
    }
    imagesPath = resolve(normalize(confKey('images.store')));
    try {
      repoInit = true;
      if (reset && fs.existsSync(repository)) {
        try {
          removeSync(repository);
          logger.debug("previous git repository removed...");
        } catch (_error) {
          err = _error;
          repoInit = false;
          return callback(err);
        }
      }
      enforceFolderSync(root, false, logger);
      enforceFolderSync(executables, false, logger);
      enforceFolderSync(imagesPath, false, logger);
      enforceFolderSync(resolve(normalize(confKey('game.executable.target'))), false, logger);
      finished = function(err) {
        var repo;
        if (err) {
          repoInit = false;
          return callback(err);
        }
        repo = git(repository);
        return repo.git('config', {}, ['--file', join(repository, '.git', 'config'), 'user.name', 'mythic-forge'], function(err) {
          if (err) {
            repoInit = false;
            return callback(err);
          }
          return repo.git('config', {}, ['--file', join(repository, '.git', 'config'), 'user.email', 'mythic.forge.adm@gmail.com'], function(err) {
            if (err) {
              repoInit = false;
              return callback(err);
            }
            return repo.git('config', {}, ['--file', join(repository, '.git', 'config'), 'core.autocrlf', 'false'], function(err) {
              if (err) {
                repoInit = false;
                return callback(err);
              }
              logger.debug("git repository initialized !");
              repoInit = false;
              return callback(null, root, repo);
            });
          });
        });
      };
      if (!fs.existsSync(join(repository, '.git'))) {
        logger.debug("initialize git repository at " + repository + "...");
        return git.init(repository, finished);
      } else {
        logger.debug("using existing git repository...");
        return finished();
      }
    } catch (_error) {
      err = _error;
      repoInit = false;
      return callback(err);
    }
  },
  quickTags: quickTags,
  quickHistory: quickHistory,
  listRestorables: function(repo, callback) {
    return repo.git('log', {
      'diff-filter': 'D',
      'name-only': true,
      pretty: 'format:"%H"'
    }, (function(_this) {
      return function(err, stdout, stderr) {
        var commitId, line, lines, paths, putInRestorables, restorables, _i, _len;
        if ((err != null ? err.code : void 0) === 1 || (err != null ? err.code : void 0) === 128) {
          err = null;
        }
        if (err != null) {
          return callback("failed to read restorables: " + err + " " + stderr);
        }
        restorables = [];
        lines = stdout.split('\n');
        commitId = null;
        paths = [];
        putInRestorables = function() {
          var path, _i, _len;
          for (_i = 0, _len = paths.length; _i < _len; _i++) {
            path = paths[_i];
            restorables.push({
              id: commitId,
              path: path
            });
          }
          commitId = null;
          return paths = [];
        };
        for (_i = 0, _len = lines.length; _i < _len; _i++) {
          line = lines[_i];
          if (commitId === null) {
            commitId = line;
          } else if (line === '') {
            putInRestorables();
          } else {
            paths.push(line.replace('"', ''));
          }
        }
        putInRestorables();
        restorables = _.uniq(restorables, false, function(element) {
          return element.path;
        });
        return callback(null, restorables);
      };
    })(this));
  }
};
