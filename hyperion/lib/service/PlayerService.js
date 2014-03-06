
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
var Item, Player, PlayerService, deployementService, expiration, logger, moment, notifier, utils, _, _PlayerService, _instance,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

moment = require('moment');

_ = require('underscore');

Player = require('../model/Player');

Item = require('../model/Item');

utils = require('../util/common');

deployementService = require('./DeployementService').get();

notifier = require('../service/Notifier').get();

logger = require('../util/logger').getLogger('service');

expiration = utils.confKey('authentication.tokenLifeTime');

_instance = void 0;

module.exports = PlayerService = (function() {
  function PlayerService() {}

  PlayerService.get = function() {
    return _instance != null ? _instance : _instance = new _PlayerService();
  };

  return PlayerService;

})();

_PlayerService = (function() {
  _PlayerService.prototype.connectedList = [];

  function _PlayerService() {
    this._setTokens = __bind(this._setTokens, this);
    this.disconnect = __bind(this.disconnect, this);
    this.getByToken = __bind(this.getByToken, this);
    this.getByEmail = __bind(this.getByEmail, this);
    this.authenticatedFromTwitter = __bind(this.authenticatedFromTwitter, this);
    this.authenticatedFromGoogle = __bind(this.authenticatedFromGoogle, this);
    this.authenticate = __bind(this.authenticate, this);
    this.register = __bind(this.register, this);
    this.activity = __bind(this.activity, this);
    this.connectedList = [];
    this.activity = _.throttle(this.activity, 60000);
    Player.findOne({
      email: 'admin'
    }, (function(_this) {
      return function(err, result) {
        if (err != null) {
          throw "Unable to check admin account existence: " + err;
        }
        if (result != null) {
          return logger.info('"admin" account already exists');
        }
        return new Player({
          email: 'admin',
          password: 'admin',
          isAdmin: true
        }).save(function(err) {
          if (err != null) {
            throw "Unable to create admin account: " + err;
          }
          return logger.warn('"admin" account has been created with password "admin". Please change it immediately');
        });
      };
    })(this));
  }

  _PlayerService.prototype.activity = function(email) {
    return Player.findOne({
      email: email
    }, (function(_this) {
      return function(err, player) {
        var now;
        if ((err != null) || player === null) {
          return;
        }
        now = new moment();
        now.milliseconds(0);
        now.subtract('seconds', 60);
        player.lastConnection = now.toDate();
        if (__indexOf.call(_this.connectedList, email) < 0) {
          _this.connectedList.push(email);
          notifier.notify('players', 'connect', player);
        }
        return player.save();
      };
    })(this));
  };

  _PlayerService.prototype.register = function(email, password, callback) {
    if (!email) {
      return callback('Email is mandatory');
    }
    if (!password) {
      return callback('Password is mandatory');
    }
    logger.info("Register new player with email: " + email);
    return this.getByEmail(email, false, function(err, player) {
      if (err != null) {
        return callback("Can't check email unicity: " + err, null);
      }
      if (player != null) {
        return callback("Email " + email + " is already used", null);
      }
      return new Player({
        email: email,
        password: password
      }).save(function(err, newPlayer) {
        logger.info("New player (" + newPlayer.id + ") registered with email: " + email);
        return callback(err, Player.purge(newPlayer));
      });
    });
  };

  _PlayerService.prototype.authenticate = function(email, password, callback) {
    logger.debug("Authenticate player with email: " + email);
    return this.getByEmail(email, false, (function(_this) {
      return function(err, player) {
        if (err != null) {
          return callback("Failed to check player existence: " + err);
        }
        if (player === null || !player.checkPassword(password)) {
          return callback(null, false, {
            type: 'error',
            message: 'Wrong credentials'
          });
        }
        return _this._setTokens(player, 'Manual', callback);
      };
    })(this));
  };

  _PlayerService.prototype.authenticatedFromGoogle = function(accessToken, refreshToken, profile, callback) {
    var email;
    email = profile.emails[0].value;
    if (email == null) {
      return callback('No email found in profile');
    }
    logger.debug("Authenticate Google player with email: " + email);
    return this.getByEmail(email, false, (function(_this) {
      return function(err, player) {
        if (err != null) {
          return callback("Failed to check player existence: " + err);
        }
        if (player == null) {
          logger.info("Register Google player with email: " + email);
          player = new Player({
            email: email,
            provider: 'Google',
            firstName: profile.name.givenName,
            lastName: profile.name.familyName
          });
        }
        return _this._setTokens(player, 'Google', callback);
      };
    })(this));
  };

  _PlayerService.prototype.authenticatedFromTwitter = function(accessToken, refreshToken, profile, callback) {
    var email;
    email = profile.username;
    if (email == null) {
      return callback('No email found in profile');
    }
    logger.debug("Authenticate Twitter player with email: " + email);
    return this.getByEmail(email, false, (function(_this) {
      return function(err, player) {
        if (err != null) {
          return callback("Failed to check player existence: " + err);
        }
        if (player == null) {
          logger.info("Register Twitter player with email: " + email);
          player = new Player({
            email: email,
            provider: 'Twitter',
            firstName: profile.displayName.split(' ')[1] || '',
            lastName: profile.displayName.split(' ')[0] || ''
          });
        }
        return _this._setTokens(player, 'Twitter', callback);
      };
    })(this));
  };

  _PlayerService.prototype.getByEmail = function(email, withLinked, callback) {
    var _ref;
    if ('function' === utils.type(withLinked)) {
      _ref = [withLinked, false], callback = _ref[0], withLinked = _ref[1];
    }
    logger.debug("consult player by email: " + email);
    return Player.findOne({
      email: email
    }, (function(_this) {
      return function(err, player) {
        if (err != null) {
          return callback(err, null);
        }
        if ((player != null) && player.characters.length !== 0 && withLinked) {
          logger.debug('resolves its character');
          return Item.fetch(player.characters, function(err, instances) {
            if (err != null) {
              return callback(err, null);
            }
            player.characters = instances;
            return callback(null, player);
          });
        } else {
          return callback(null, player);
        }
      };
    })(this));
  };

  _PlayerService.prototype.getByToken = function(token, callback) {
    return Player.findOne({
      token: token
    }, (function(_this) {
      return function(err, player) {
        if (err != null) {
          return callback(err, null);
        }
        if (player == null) {
          return callback(null, null);
        }
        if ((deployementService.deployedVersion() != null) && !player.isAdmin) {
          return callback('Deployment in progress', null);
        }
        if (player.lastConnection.getTime() + expiration * 1000 < new Date().getTime()) {
          player.token = null;
          return player.save(function(err, saved) {
            var idx;
            if (err != null) {
              return callback("Failed to reset player's expired token: " + err);
            }
            idx = _this.connectedList.indexOf(saved.email);
            if (idx !== -1) {
              _this.connectedList.splice(idx, 1);
              notifier.notify('players', 'disconnect', saved, 'expired');
            }
            return callback("Expired token");
          });
        } else {
          player.token = utils.generateToken(24);
          return player.save(function(err, saved) {
            if (err != null) {
              return callback("Failed to change player's token: " + err);
            }
            return callback(null, saved);
          });
        }
      };
    })(this));
  };

  _PlayerService.prototype.disconnect = function(email, reason, callback) {
    if (callback == null) {
      callback = function() {};
    }
    return Player.findOne({
      email: email
    }, (function(_this) {
      return function(err, player) {
        if (err != null) {
          return callback(err);
        }
        if (player == null) {
          return callback("No player with email " + email + " found");
        }
        player.token = null;
        return player.save(function(err, saved) {
          var idx;
          if (err != null) {
            return callback("Failed to reset player's token: " + err);
          }
          idx = _this.connectedList.indexOf(email);
          if (idx !== -1) {
            _this.connectedList.splice(idx, 1);
            notifier.notify('players', 'disconnect', saved, reason);
          }
          return callback(null, saved);
        });
      };
    })(this));
  };

  _PlayerService.prototype._setTokens = function(player, provider, callback) {
    var now, token;
    token = utils.generateToken(24);
    player.token = token;
    now = new Date();
    now.setMilliseconds(0);
    player.set('lastConnection', now);
    return player.save((function(_this) {
      return function(err, newPlayer) {
        var _ref;
        if (err != null) {
          return callback("Failed to update player: " + err);
        }
        logger.info("" + provider + " player (" + newPlayer.id + ") authenticated with email: " + player.email);
        if (_ref = newPlayer.email, __indexOf.call(_this.connectedList, _ref) < 0) {
          _this.connectedList.push(newPlayer.email);
        }
        notifier.notify('players', 'connect', newPlayer);
        return callback(null, token, newPlayer);
      };
    })(this));
  };

  return _PlayerService;

})();
