
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
var Field, FieldSchema, Map, ObjectId, conn, logger, modelWatcher, mongoose;

mongoose = require('mongoose');

ObjectId = require('mongodb').BSONPure.ObjectID;

conn = require('./connection');

modelWatcher = require('./ModelWatcher').get();

Map = require('./Map');

logger = require('../util/logger').getLogger('model');

FieldSchema = new mongoose.Schema({
  _id: String,
  mapId: {
    type: String,
    required: true
  },
  typeId: {
    type: String,
    required: true
  },
  num: {
    type: Number,
    "default": 0
  },
  x: {
    type: Number,
    "default": 0
  },
  y: {
    type: Number,
    "default": 0
  }
}, {
  strict: true,
  _id: false,
  toJSON: {
    transform: function(doc, ret, options) {
      ret.id = ret._id;
      delete ret._id;
      delete ret.__v;
      return ret;
    }
  }
});

FieldSchema.methods.equals = function(object) {
  return this.id === (object != null ? object.id : void 0);
};

FieldSchema.virtual('id').set(function(value) {
  return this._id = value;
});

FieldSchema.pre('save', function(next) {
  if (!this.isNew) {
    return next(new Error('only creations are allowed on fields'));
  }
  this.id = new ObjectId().toString();
  return next();
});

FieldSchema.post('save', function() {
  return modelWatcher.change('creation', 'Field', this);
});

FieldSchema.post('remove', function() {
  return modelWatcher.change('deletion', 'Field', this);
});

Field = conn.model('field', FieldSchema);

module.exports = Field;
