###
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
###
'use strict'

mongoose = require 'mongoose'
conn = require './connection'
modelWatcher = require('./ModelWatcher').get()
Map = require './Map'
logger = require('../logger').getLogger 'model'

# We use the post-save middleware to propagate creation and saves.
# But within this function, all instances have lost their "isNew" status
# thus we store that status from the pre-save middleware, to use it in the post-save
# middleware 
wasNew = {}
modifiedPaths = {}

# Define the schema for maps.
FieldSchema = new mongoose.Schema {
  # link to map
  map: {type: {}, required: true}
  # coordinates on the map
  x: 
    type:Number
    required: true
    default: 0
  y: 
    type:Number
    required: true
    default: 0
}, {strict:true}

# Override the equals() method defined in Document, to check correctly the equality between _ids, 
# with their `equals()` method and not with the strict equality operator.
#
# @param other [Object] other object against which the current object is compared
# @return true if both objects have the same _id, false otherwise
FieldSchema.methods.equals = (object) ->
  @_id.equals object?._id
        
# pre-save middleware: store new and modified paths
#
# @param next [Function] function that must be called to proceed with other middleware.
# Calling it with an argument indicates the the validation failed and cancel the item save.
FieldSchema.pre 'save', (next) ->
  # stores the isNew status.
  wasNew[@_id] = @isNew
  modifiedPaths[@_id] = @modifiedPaths.concat()
  # replace map with its id, for storing in Mongo, without using setters.
  save = @map
  @_doc.map = save._id
  next()
  # restore save to allow reference reuse.
  @_doc.map = save

# post-save middleware: now that the instance was properly saved, propagate its modifications
FieldSchema.post 'save', () ->
  modelWatcher.change (if wasNew[@_id] then 'creation' else 'update'), 'Field', this, modifiedPaths[@_id]

# post-remove middleware: now that the instace was properly removed, propagate the removal.
FieldSchema.post 'remove', () ->
  modelWatcher.change 'deletion', 'Field', this

# pre-init middleware: retrieve the map corresponding to the stored id.
#
# @param field [Field] the initialized field.
# @param next [Function] function that must be called to proceed with other middleware.
FieldSchema.pre 'init', (next, field) ->
  # loads the type
  Map.findCached field.map, (err, map) ->
    return next(new Error "Unable to init field #{field._id}. Error while resolving its type: #{err}") if err?
    return next(new Error "Unable to init field #{field._id} because there is no map with id #{field.map}") unless map?    
    # Do the replacement.
    field.map = map
    next();

# Export the Class.
Field = conn.model 'field', FieldSchema
module.exports = Field