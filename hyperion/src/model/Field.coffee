###
  Copyright 2010~2014 Damien Feugas
  
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
###
'use strict'

mongoose = require 'mongoose'
ObjectId = require('mongodb').BSONPure.ObjectID
conn = require './connection'
modelWatcher = require('./ModelWatcher').get()
Map = require './Map'
logger = require('../util/logger').getLogger 'model'

# Define the schema for fields.
FieldSchema = new mongoose.Schema 
  # manually managed id
  _id: String

  # link to map
  mapId: 
    type: String
    required: true

  # link to type
  typeId: 
    type: String
    required: true

  # image num
  num: 
    type: Number
    default: 0

  # coordinates on the map
  x: 
    type:Number
    default: 0
  y: 
    type:Number
    default: 0
, 
  strict: true
  _id: false
  # Extends original Mongoose toJSON method to change _id to id.
  toJSON:
    transform: (doc, ret, options) ->
      ret.id = ret._id
      delete ret._id
      delete ret.__v
      ret

# Override the equals() method defined in Document, to check correctly the equality between _ids, 
# with their `equals()` method and not with the strict equality operator.
#
# @param other [Object] other object against which the current object is compared
# @return true if both objects have the same _id, false otherwise
FieldSchema.methods.equals = (object) ->
  @id is object?.id
   
# manually manage ids within the 'id' attribute, and store them into the '_id' attribute.
# Define a virtual getter on model's class name.
# Handy when models have been serialized to distinguish them
FieldSchema.virtual('id').set (value) -> @_id = value

# pre-save middleware: only allow save of new fields. Do not allow updates
#
# @param next [Function] function that must be called to proceed with other middleware.
# Calling it with an argument indicates the the validation failed and cancel the item save.
FieldSchema.pre 'save', (next) ->
  # wuit with an error if the field isn't new
  return next new Error 'only creations are allowed on fields' unless @isNew
  @id = new ObjectId().toString()
  next()

# post-save middleware: now that the instance was properly saved, propagate its modifications
FieldSchema.post 'save', () ->
  modelWatcher.change 'creation', 'Field', @

# post-remove middleware: now that the instace was properly removed, propagate the removal.
FieldSchema.post 'remove', () ->
  modelWatcher.change 'deletion', 'Field', @

# Export the Class.
Field = conn.model 'field', FieldSchema
module.exports = Field