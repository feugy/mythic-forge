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
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

mongoose = require 'mongoose'
utils = require '../utils'
fs = require 'fs'
path = require 'path'
modelWatcher = require('./ModelWatcher').get()
imageStore = require('../utils').confKey('images.store')

# Factory that creates an abstract type.
# Provides:
# - `name` and `desc` i18n attributes
# - id-based `equals` method
# - modelWatcher usage
# - cache functionnalities and `findCached` static method
# - image storage with `saveImage`and `removeImage`
#
# @param typeName [String] name of the build type, used for changes propagations
# @param attrs [Object] attributes of the created type.
# @param options [Object] Mongoose schema options, and factory custom options:
# @option options noDesc [Boolean] wether this type has a description or not.
module.exports = (typeName, spec, options = {}) ->

  # Local cache
  cache = {}

  # We use the post-save middleware to propagate creation and saves.
  # But within this function, all instances have lost their "isNew" status
  # thus we store that status from the pre-save middleware, to use it in the post-save
  # middleware 
  wasNew = {}
  modifiedPaths = {}

  # Abstract schema, that can contains i18n attributes
  AbstractType = new mongoose.Schema spec, options

  utils.enhanceI18n AbstractType

  # Adds an i18n `name` field which is required
  utils.addI18n AbstractType, 'name', {required: true}

  unless options?.noDesc
    # Adds an i18n `desc` field
    utils.addI18n AbstractType, 'desc'

  # Override the equals() method defined in Document, to check correctly the equality between _ids, 
  # with their `equals()` method and not with the strict equality operator.
  #
  # @param other [Object] other object against which the current object is compared
  # @return true if both objects have the same _id, false otherwise
  AbstractType.methods.equals = (object) ->
    @_id.equals object?._id

  # This special finder maintains an in-memory cache of types, to faster type retrieval by ids.
  # If the id isn't found in cache, search in database.
  #
  # @param id [String] the type id.
  # @param callback [Function] the callback function, that takes two parameters
  # @option callback err [String] an error string, or null if no error occured
  # @option callback type [ItemType] the found type, or null if no type found for the id
  AbstractType.statics.findCached = (id, callback) ->
    # first look in the cache
    return callback null, cache[id] if id of cache
    # nothing in the cache: search in database
    @findOne {_id: id}, callback
  
  # pre-save middleware: store modified path for changes propagation
  AbstractType.pre 'save', (next) ->
    # stores the isNew status and modified paths.
    wasNew[@_id] = @isNew
    modifiedPaths[@_id] = @modifiedPaths.concat()
    next()

  # post-save middleware: now that the instance was properly saved, update the cache.
  AbstractType.post 'save', ->
    # updates the cache
    cache[@_id] = @
    modelWatcher.change (if wasNew[@_id] then 'creation' else 'update'), typeName, this, modifiedPaths[@_id]
    
  # post-remove middleware: now that the type was properly removed, update the cache.
  AbstractType.post 'remove', ->
    # updates the cache
    delete cache[@_id]
    # broadcast deletion
    modelWatcher.change 'deletion', typeName, this

  # post-init middleware: populate the cache
  AbstractType.post 'init', ->
    # store in cache
    cache[@_id] = @

  # post-remove middleware: removes images, without using the ImageService
  AbstractType.post 'remove', ->
    # removes all images that starts with the id from the image store.
    id = @_id
    fs.readdir imageStore, (err, files) ->
      for file in files when file.indexOf("#{id}-") is 0
        fs.unlink path.join imageStore, file

  return AbstractType