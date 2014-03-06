
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
var Map, conn, logger, modelUtils, modelWatcher, typeFactory;

typeFactory = require('./typeFactory');

conn = require('./connection');

logger = require('../util/logger').getLogger('model');

modelWatcher = require('./ModelWatcher').get();

modelUtils = require('../util/model');

Map = typeFactory('Map', {
  kind: {
    type: String,
    "default": 'hexagon'
  },
  tileDim: {
    type: Number,
    "default": 100
  }
}, {
  strict: true,
  middlewares: {
    save: function(next) {
      if (!this.isNew) {
        return next();
      }
      return modelUtils.addConfKey(this.id, 'names', this.id, logger, next);
    },
    remove: function(next) {
      require('./Field').where('mapId', this.id).remove((function(_this) {
        return function(err) {
          if (err != null) {
            return logger.error("Faild to remove fields of deleted map " + _this.id + ": " + err);
          }
        };
      })(this));
      return require('./Item').where('map', this.id).select({
        _id: 1
      }).lean().exec((function(_this) {
        return function(err, objs) {
          if (err != null) {
            return logger.error("Faild to select items of deleted map " + _this.id + ": " + err);
          }
          return require('./Item').where('map', _this.id).remove(function(err) {
            var obj, _i, _len;
            if (err != null) {
              return logger.error("Faild to remove items of deleted map " + _this.id + ": " + err);
            }
            for (_i = 0, _len = objs.length; _i < _len; _i++) {
              obj = objs[_i];
              modelWatcher.change('deletion', 'Item', obj);
            }
            return next();
          });
        };
      })(this));
    }
  }
});

module.exports = conn.model('map', Map);
