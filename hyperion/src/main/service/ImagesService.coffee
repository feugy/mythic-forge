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

_ = require 'underscore'
fs = require 'fs'
path= require 'path'
utils = require '../utils'
ItemType = require '../model/ItemType'
logger = require('../logger').getLogger 'service'

# enforce folder existence
utils.enforceFolderSync utils.confKey('images.store'), false, logger


# The ImagesService allow to save and remove images associated to a given model.
# It saved all images in a folder, which path is read in configuration at key `images.store`.
# Images are renamed with the id of the given type, and a suffix (`type` or the instance image id).
# It's a singleton class. The unic instance is retrieved by the `get()` method.
class _ImagesService

  # Saves an new or existing image for a given model.
  # Can save the type image or an instance image.
  # The model is updated in database.
  #
  # @param modelName [String] class name of the saved model
  # @param id [String] the concerned model's id
  # @param meta [Object] the image metadata:
  # @option meta ext [String] the image extension, mandatory for all images
  # @param imageData [String] image base-64 string data
  # @param callback [Function] end callback. Walled with two parameters
  # @option callback err [String] error message. Null if no error occured
  # @option callback model [Object] the saved model
  #
  # @overload uploadImage(modelName, id, meta, imageData, callback)
  #   Saves the type image of the given model
  #
  # @overload uploadImage(modelName, id, meta, imageData, idx, callback)
  #   Saves an instance image of the given model at a given index
  #   @param idx [Number] index of the saved instance image
  uploadImage: (modelName, id, meta, imageData, args...) =>
    return callback "No image can be uploaded for #{modelName}" unless modelName in ['ItemType']
    modelClass = null
    switch modelName
      when 'ItemType' then modelClass = ItemType

    # gets the concerned model
    modelClass.findCached id, (err, model) ->
      return callback "Unexisting #{modelName} with id #{id}: #{err}" if err?

      switch args.length
        when 1 
          callback = args[0]
          suffix = 'type'
          existing = model.get 'descImage'
        when 2 
          callback = args[1]
          suffix = args[0]
          # check suffix validity
          return callback "idx argument #{suffix} isn't a positive number" unless _.isNumber(suffix) and suffix >= 0
          existing = model.get('images')[suffix]?.file
        else throw new Error "save must be called with arguments (modelName, id, meta, imageData, [idx], callback)"

      imagesPath = utils.confKey 'images.store'

      proceed = (err) =>
        return callback "Failed to save image #{suffix} on model #{model._id}: #{err}" if err? and err.code isnt 'ENOENT'
        fileName = "#{model._id}-#{suffix}.#{meta.ext}"
        fs.writeFile path.join(imagesPath, fileName), new Buffer(imageData, 'base64'), (err) =>
          return callback "Failed to save image #{suffix} on model #{model._id}: #{err}" if err?
          # updates correct attribute
          if args.length is 1
            model.set 'descImage', fileName
          else 
            images = model.get 'images'
            # save meta data at correct index
            images[suffix] = _.extend {file:fileName}, meta
            delete images[suffix].ext
            model.set 'images', images
          # saves model
          model.save (err, saved) =>
            if err?
              # removes image
              fs.unlink path.join imagesPath, fileName
              return callback "Failed to save image #{suffix} on model #{model._id}: #{err}"
            # everything's fine
            callback null, saved

      # removes the existing file if necessary
      if existing
        fs.unlink path.join(imagesPath, existing), proceed
      else 
        proceed()

  # Removes an existing image of this type.
  # Can remove the type image or an instance image
  # The model is updated in database.
  #
  # @param modelName [String] class name of the saved model
  # @param id [String] the concerned model's id
  # @param callback [Function] end callback. Walled with two parameters
  # @option callback err [String] error message. Null if no error occured
  # @option callback model [Object] the saved model
  #
  # @overload removeImage(modelName, id, callback)
  #   Removes the type image of the given model
  #
  # @overload removeImage(modelName, id, idx, callback)
  #   Removes an instance image of the given model at a given index
  #   @param idx [Number] index of the saved instance image
  removeImage: (modelName, id, args...) =>
    return callback "No image can be uploaded for #{modelName}" unless modelName in ['ItemType']
    modelClass = null
    switch modelName
      when 'ItemType' then modelClass = ItemType

    # gets the concerned model
    modelClass.findCached id, (err, model) ->
      return callback "Unexisting #{modelName} with id #{id}: #{err}" if err?

      switch args.length
        when 1 
          callback = args[0]
          suffix = 'type'
          existing = model.get 'descImage'
        when 2 
          callback = args[1]
          suffix = args[0]
          # check suffix validity
          return callback "idx argument #{suffix} isn't a positive number" unless _.isNumber(suffix) and suffix >= 0
          existing = model.get('images')[suffix]?.file
        else throw new Error "semove must be called with arguments (model, [idx], callback)"
      
      imagesPath = utils.confKey 'images.store'

      # removes the existing file
      fs.unlink path.join(imagesPath, existing), (err) =>
        return callback "Failed to remove image #{suffix} on model #{model._id}: #{err}" if err? and err.code isnt 'ENOENT'
        # updates correct attribute
        if args.length is 1
          model.set 'descImage', null
        else 
          images = model.get 'images'
          # removes correct index
          images.splice suffix, 1
          model.set 'images', images
        # save model
        model.save (err, saved) =>
          return callback "Failed to remove image #{suffix} on model #{model._id}: #{err}" if err?
          # everything's fine
          callback null, saved

_instance = undefined
class ImagesService
  @get: ->
    _instance ?= new _ImagesService()

module.exports = ImagesService