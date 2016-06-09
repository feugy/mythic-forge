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

_ = require 'lodash'
fs = require 'fs-extra'
{join, normalize, resolve} = require 'path'
{confKey, fromRule} = require '../util/common'
ItemType = require '../model/ItemType'
FieldType = require '../model/FieldType'
EventType = require '../model/EventType'
logger = require('../util/logger').getLogger 'service'

imagesPath = resolve normalize confKey 'game.image'
supported = ['ItemType', 'FieldType', 'EventType']

# The ImagesService allow to save and remove images associated to a given model.
# It saved all images in a folder, which path is read in configuration at key `game.image`.
# Images are renamed with the id of the given type, and a suffix (`type` or the instance image id).
# It's a singleton class. The unic instance is retrieved by the `get()` method.
class _ImagesService

  # Saves an new or existing image for a given model.
  # Can save the type image or an instance image.
  # The model is updated in database.
  #
  # @param modelName [String] class name of the saved model
  # @param id [String] the concerned model's id
  # @param ext [String] the image extension, mandatory for all images
  # @param imageData [String] image base-64 string data
  # @param callback [Function] end callback. Walled with two parameters
  # @option callback err [String] error message. Null if no error occured
  # @option callback model [Object] the saved model
  #
  # @overload uploadImage(modelName, id, ext, imageData, callback)
  #   Saves the type image of the given model
  #
  # @overload uploadImage(modelName, id, ext, imageData, idx, callback)
  #   Saves an instance image of the given model at a given index
  #   @param idx [Number] index of the saved instance image
  uploadImage: (modelName, id, ext, imageData, args...) =>
    return if fromRule()
    switch args.length
      when 1
        callback = args[0]
        suffix = 'type'
      when 2
        callback = args[1]
        suffix = args[0]

    return callback "No image can be uploaded for #{modelName}" unless modelName in supported
    modelClass = null
    switch modelName
      when 'ItemType' then modelClass = ItemType
      when 'FieldType' then modelClass = FieldType
      when 'EventType' then modelClass = EventType

    # gets the concerned model
    modelClass.findCached [id], (err, models) ->
      return callback "Unexisting #{modelName} with id #{id}: #{err}" if err? or models.length is 0
      model = models[0]

      switch args.length
        when 1
          existing = model.descImage
        when 2
          # check suffix validity
          return callback "idx argument #{suffix} isn't a positive number" unless _.isNumber(suffix) and suffix >= 0
          existing = model.images[suffix]?.file
        else throw new Error "save must be called with arguments (modelName, id, ext, imageData, [idx], callback)"

      proceed = (err) =>
        return callback "Failed to save image #{suffix} on model #{model.id}: #{err}" if err? and err.code isnt 'ENOENT'
        fileName = "#{model.id}-#{suffix}.#{ext}"
        fs.writeFile join(imagesPath, fileName), new Buffer(imageData, 'base64'), (err) =>
          return callback "Failed to save image #{suffix} on model #{model.id}: #{err}" if err?
          # updates correct attribute
          if suffix is 'type'
            model.descImage = fileName
          else
            images = model.images
            if modelName is 'ItemType'
              # save meta data at correct index, keeping existing informations
              previous = images[suffix] || {width:0, height:0}
              previous.file = fileName
              images[suffix] = previous
            else
              # fot other, just keep the name
              images[suffix] = fileName

            model.images = images
            model.markModified 'images'
          # saves model
          model.save (err, saved) =>
            if err?
              # removes image
              fs.unlink join imagesPath, fileName
              return callback "Failed to save image #{suffix} on model #{model.id}: #{err}"
            # everything's fine
            callback null, saved

      # removes the existing file if necessary
      if existing
        fs.unlink join(imagesPath, existing), proceed
      else
        proceed()

  # Removes an existing image of this type.
  # Can remove the type image or an instance image.
  # For instance images, the file attribute inside the image array is set to null, unless the last images is removed.
  # In this case, the image array is shortened.
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
    return if fromRule()
    switch args.length
      when 1
        callback = args[0]
        suffix = 'type'
      when 2
        callback = args[1]
        suffix = args[0]

    return callback "No image can be uploaded for #{modelName}" unless modelName in supported
    modelClass = null
    switch modelName
      when 'ItemType' then modelClass = ItemType
      when 'FieldType' then modelClass = FieldType
      when 'EventType' then modelClass = EventType

    # gets the concerned model
    modelClass.findCached [id], (err, models) ->
      return callback "Unexisting #{modelName} with id #{id}: #{err}" if err? or models.length is 0
      model = models[0]

      switch args.length
        when 1
          existing = model.descImage
        when 2
          # check suffix validity
          return callback "idx argument #{suffix} isn't a positive number" unless _.isNumber(suffix) and suffix >= 0
          existing = model.images[suffix]?.file
        else throw new Error "semove must be called with arguments (model, [idx], callback)"

      # removes the existing file
      fs.unlink join(imagesPath, existing), (err) =>
        return callback "Failed to remove image #{suffix} on model #{model.id}: #{err}" if err? and err.code isnt 'ENOENT'
        # updates correct attribute
        if args.length is 1
          model.descImage = null
        else
          images = model.images
          # removes correct index
          if suffix is images.length-1
            images.splice suffix, 1
          else
            if modelName is 'ItemType'
              images[suffix].file = null
            else
              images[suffix] = null

          model.images = images
          model.markModified 'images'
        # save model
        model.save (err, saved) =>
          return callback "Failed to remove image #{suffix} on model #{model.id}: #{err}" if err?
          # everything's fine
          callback null, saved

_instance = undefined
class ImagesService
  @get: ->
    _instance ?= new _ImagesService()

module.exports = ImagesService