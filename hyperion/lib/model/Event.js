
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
var Event, Item, conn, modelUtils, typeFactory;

typeFactory = require('./typeFactory');

Item = require('./Item');

conn = require('./connection');

modelUtils = require('../util/model');

Event = typeFactory('Event', {
  created: {
    type: Date,
    "default": function() {
      return new Date();
    }
  },
  updated: {
    type: Date,
    "default": function() {
      return new Date();
    }
  },
  from: {
    type: {},
    "default": function() {
      return null;
    }
  }
}, {
  instanceProperties: true,
  typeClass: 'EventType',
  strict: false,
  middlewares: {
    init: function(next, event) {
      if (event.from == null) {
        return next();
      }
      return Item.findById(event.from, function(err, item) {
        var _ref;
        if (err != null) {
          return next(new Error("Unable to init event " + event.id + ". Error while resolving its from: " + err));
        }
        event.from = item;
        if (event.from != null) {
          modelUtils.processLinks(event.from, event != null ? (_ref = event.type) != null ? _ref.properties : void 0 : void 0, false);
        }
        return next();
      });
    },
    save: function(next) {
      var saveFrom;
      if (this.isModified('created')) {
        return next(new Error('creation date cannot be modified for an Event'));
      }
      this.updated = new Date();
      saveFrom = this.from;
      this._doc.from = saveFrom != null ? saveFrom.id : void 0;
      next();
      return this._doc.from = saveFrom;
    }
  }
});

module.exports = conn.model('event', Event);
