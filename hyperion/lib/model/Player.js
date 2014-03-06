
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
var Item, Player, conn, encryptor, logger, typeFactory, utils, _;

_ = require('underscore');

encryptor = require('password-hash');

conn = require('./connection');

Item = require('./Item');

typeFactory = require('./typeFactory');

utils = require('../util/common');

logger = require('../util/logger').getLogger('model');

Player = typeFactory('Player', {
  email: {
    type: String,
    required: true
  },
  provider: {
    type: String,
    "default": null
  },
  lastConnection: Date,
  firstName: String,
  lastName: String,
  isAdmin: {
    type: Boolean,
    "default": false
  },
  characters: {
    type: {},
    "default": function() {
      return [];
    }
  },
  prefs: {
    type: {},
    "default": function() {
      return {};
    }
  },
  token: String,
  socketId: String,
  key: String,
  password: {
    type: String,
    "default": null
  }
}, {
  strict: true,
  middlewares: {
    init: function(next, player) {
      if (!_.isArray(player.characters)) {
        player.characters = [];
      }
      this.__origcharacters = [];
      this.__origprefs = JSON.stringify(player.prefs || {});
      if (player.characters.length === 0) {
        return next();
      }
      return Item.findCached(player.characters, (function(_this) {
        return function(err, characters) {
          var character, final, id, _i, _len, _ref;
          if (err != null) {
            return next(new Error("Unable to init item " + player.id + ". Error while resolving its character: " + err));
          }
          final = [];
          _ref = player.characters;
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            id = _ref[_i];
            character = _.find(characters, function(c) {
              return c.id === id;
            });
            if (character != null) {
              final.push(character);
              _this.__origcharacters.push(id);
            }
          }
          player.characters = final;
          return next();
        };
      })(this));
    },
    save: function(next) {
      var err, process;
      try {
        JSON.parse('string' === utils.type(this._doc.prefs) ? this._doc.prefs : JSON.stringify(this._doc.prefs || {}));
      } catch (_error) {
        err = _error;
        return next(new Error("JSON syntax error for 'prefs': " + err));
      }
      process = (function(_this) {
        return function() {
          var character, i, saveCharacters, _i, _len;
          if (_this.password != null) {
            if (!encryptor.isHashed(_this.password)) {
              _this.password = encryptor.generate(_this.password);
            }
          }
          saveCharacters = _this.characters.concat();
          for (i = _i = 0, _len = saveCharacters.length; _i < _len; i = ++_i) {
            character = saveCharacters[i];
            if ((character != null ? character.id : void 0) != null) {
              _this._doc.characters[i] = character.id;
            }
          }
          next();
          _this.__origcharacters = _this._doc.characters.concat() || [];
          _this.__origprefs = JSON.stringify(_this._doc.prefs || {});
          return _this._doc.characters = saveCharacters;
        };
      })(this);
      if (this.provider === null && !this.password) {
        return this.constructor.findOne({
          _id: this.id
        }, function(err, player) {
          if (err != null) {
            return next(new Error("Cannot check password existence in db for player " + this.id + ": " + err));
          }
          if ((player != null ? player.get('password') : void 0) == null) {
            return next(new Error("Cannot save manually provided account without password"));
          }
          return process();
        });
      } else {
        return process();
      }
    }
  }
});

Player.methods.checkPassword = function(clearPassword) {
  return encryptor.verify(clearPassword, this.password);
};

Player.statics.purge = function(player) {
  if ('object' !== utils.type(player)) {
    return player;
  }
  if ('_doc' in player) {
    delete player._doc.password;
    delete player._doc.token;
    delete player._doc.key;
    delete player._doc.socketId;
  } else {
    delete player.password;
    delete player.token;
    delete player.key;
    delete player.socketId;
  }
  return player;
};

module.exports = conn.model('player', Player);
