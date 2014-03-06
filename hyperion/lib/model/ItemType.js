
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
var Item, ItemType, async, conn, logger, modelUtils, typeFactory;

async = require('async');

typeFactory = require('./typeFactory');

conn = require('./connection');

logger = require('../util/logger').getLogger('model');

Item = require('./Item');

modelUtils = require('../util/model');

ItemType = typeFactory('ItemType', {
  descImage: {
    type: String
  },
  quantifiable: {
    type: Boolean,
    "default": false
  },
  images: {
    type: [],
    "default": function() {
      return [];
    }
  }
}, {
  typeProperties: true,
  instanceClass: 'Item',
  hasImages: true,
  middlewares: {
    save: function(next) {
      var process;
      process = (function(_this) {
        return function() {
          var quantity;
          if (_this.isModified('quantifiable')) {
            quantity = _this.get('quantifiable') ? quantity = 0 : quantity = null;
            next();
            return Item.find({
              type: _this.id
            }, function(err, instances) {
              if (err != null) {
                return next(new Error("Failed to update type instances: " + err));
              }
              return async.forEach(instances, function(instance, done) {
                instance.quantity = quantity;
                return instance.save(done);
              });
            });
          } else {
            return next();
          }
        };
      })(this);
      if (!this.isNew) {
        return process();
      }
      return modelUtils.addConfKey(this.id, 'names', this.id, logger, process);
    }
  }
});

module.exports = conn.model('itemType', ItemType);
