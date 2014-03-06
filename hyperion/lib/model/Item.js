
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
var Item, Map, conn, typeFactory;

typeFactory = require('./typeFactory');

conn = require('./connection');

Map = require('./Map');

Item = typeFactory('Item', {
  map: {},
  x: {
    type: Number,
    "default": null
  },
  y: {
    type: Number,
    "default": null
  },
  imageNum: {
    type: Number,
    "default": 0
  },
  state: {
    type: String,
    "default": null
  },
  transition: {
    type: String,
    "default": null,
    set: function(value) {
      if (value !== this._doc.transition) {
        this.markModified('transition');
      }
      return value;
    }
  },
  quantity: {
    type: Number,
    "default": null
  }
}, {
  instanceProperties: true,
  typeClass: 'ItemType',
  strict: false,
  middlewares: {
    init: function(next, item) {
      if (item.map == null) {
        return next();
      }
      return Map.findCached([item.map], function(err, maps) {
        if (err != null) {
          return next(new Error("Unable to init item " + item.id + ". Error while resolving its map: " + err));
        }
        if (maps.length !== 1) {
          return next(new Error("Unable to init item " + item.id + " because there is no map with id " + item.map));
        }
        item.map = maps[0];
        return next();
      });
    },
    save: function(next) {
      var saveMap, _ref;
      if ((_ref = this.type) != null ? _ref.get('quantifiable') : void 0) {
        if (this.get('quantity') == null) {
          this.set('quantity', 0);
        }
      } else {
        if (this.get('quantity') != null) {
          this.set('quantity', null);
        }
      }
      saveMap = this.map;
      this._doc.map = saveMap != null ? saveMap.id : void 0;
      next();
      return this._doc.map = saveMap;
    }
  }
});

module.exports = conn.model('item', Item);
