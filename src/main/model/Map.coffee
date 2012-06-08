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

mongoose = require 'mongoose'
conn = require './connection'
modelWatcher = require('./ModelWatcher').get()
logger = require('../logger').getLogger 'model'

# We use the post-save middleware to propagate creation and saves.
# But within this function, all instances have lost their "isNew" status
# thus we store that status from the pre-save middleware, to use it in the post-save
# middleware 
wasNew = {}
modifiedPaths = {}

# local cache.
cache = {}

# Define the schema for maps.
MapSchema = new mongoose.Schema {
  # map name, required
  name: {type: String, required: true}
}, {strict:true}

# This special finder maintains an in-memory cache of maps, to faster map retrieval by ids.
# If the id isn't found in cache, search in database.
#
# @param id [String] the map id.
# @param callback [Function] the callback function, that takes two parameters
# @option callback err [String] an error string, or null if no error occured
# @option callback map [Map] the found map, or null if no map found for the id
MapSchema.statics.findCached = (id, callback) ->
  # first look in the cache
  return callback null, cache[id] if id of cache
  # nothing in the cache: search in database
  @findOne {_id: id}, callback
   
# Override the equals() method defined in Document, to check correctly the equality between _ids, 
# with their `equals()` method and not with the strict equality operator.
#
# @param other [Object] other object against which the current object is compared
# @return true if both objects have the same _id, false otherwise
MapSchema.methods.equals = (object) ->
  @_id.equals object?._id
        
# pre-save middleware: store new and modified paths
#
# @param next [Function] function that must be called to proceed with other middleware.
# Calling it with an argument indicates the the validation failed and cancel the item save.
MapSchema.pre 'save', (next) ->
  # stores the isNew status.
  wasNew[@_id] = @isNew
  modifiedPaths[@_id] = @modifiedPaths.concat()
  next()

# post-save middleware: now that the instance was properly saved, propagate its modifications
#
MapSchema.post 'save', ->
  # updates the cache
  cache[@_id] = this
  # propagate changes
  modelWatcher.change (if wasNew[@_id] then 'creation' else 'update'), 'Map', this, modifiedPaths[@_id]

# post-remove middleware: now that the instace was properly removed, propagate the removal.
#
MapSchema.post 'remove', ->
  # updates the cache
  delete cache[@_id]
  # propagate changes
  modelWatcher.change 'deletion', 'Map', this

# pre-init middleware: populate the cache
#
MapSchema.post 'init', ->
  # Store in cache
  cache[@_id] = this

# Export the Class.
Map = conn.model 'map', MapSchema
module.exports = Map