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

typeFactory = require './typeFactory'
conn = require './connection'
async = require 'async'
logger = require('../logger').getLogger 'model'

# Define the schema for map item types
ItemType = typeFactory 'ItemType',

  # descriptive image for this type.
  descImage:
    type: String

  # definition of item images, stored in an array
  # @example each images is a set of sprites
  #   image: {
  #     # file path
  #     file: {type: String, required: true}
  #     # image width, in pixel
  #     width: {type: Number, required: true}
  #     # image height, in pixel
  #     height: {type: Number, required: true}
  #     # different sprites inside the images, stored by name
  #     sprites: {type: {}, default: {}}
  # @example a sprite inside an image.
  #   sprite: {
  #     # number of sprites
  #     number: {type: Number, required: true}
  #     # duration in milliseconds. Null for infinite sprite.
  #     duration: {type:Number, default: null}
  #     # The vertical offset of the sprite row in the sprite sheet.
  #     vOffset: {type:Number, default: 0}
  images: 
    type: []
    default: -> []

  # item properties definition, stored by names
  # @example property definition include
  #   property: {
  #     # property type, within: string, text, boolean, integer, float, date, array or object
  #     type: {type: String, required: true}
  #     # default value applied
  #     def: {type: {}, required: true}
  properties: 
    type: {}
    default: -> {} # use a function to force instance variable

# setProperty() adds or updates a property.
#
# @param name [String] the unic name of the property.
# @param type [String] primitive type of the property's values. Could be: string, text, boolean, integer, float, date, array or object
# @param def [Object] default value affected to the type instances.
ItemType.methods.setProperty = (name, type, def) ->
  @get('properties')[name] = {type: type, def: def}
  @markModified 'properties'
  @_updatedProps = [] unless @_updatedProps?
  @_updatedProps.push name

# unsetProperty() removes a property. All existing instances loose their own property value.
# Will throw an error if the property does not exists.
#
# @param name [String] the unic name of the property.
ItemType.methods.unsetProperty = (name) ->
  throw new Error "Unknown property #{name} for item type #{@name}" unless @get('properties')[name]?
  delete @get('properties')[name]
  @markModified 'properties'
  @_deletedProps = [] unless @_deletedProps?
  @_deletedProps.push name


# pre-save middleware: update itemType instances' properties if needed.
ItemType.pre 'save', (next) ->
  return next() unless @_updatedProps? or @_deletedProps?
  
  # get type instances
  require('./Item').find {type: @_id}, (err, items) =>
    saved = []
    for item in items
      # add default value in instances that do not have the added properties yet.
      if @_updatedProps?
        for name in @_updatedProps
          prop = @get('properties')[name]
          def = prop.def
          switch prop.type
            when 'array' then def = []
            when 'object' then def = null

          if not(name of item)
            item.set name, def
            saved.push item unless saved in item
          # TODO: check value type. 

      # removes deleted properties from instances.
      if @_deletedProps?
        for name in @_deletedProps
          item.set name, undefined
          delete item._doc[name]
          saved.push item unless saved in item

    delete @_deletedProps
    delete @_updatedProps
    # save all the modified instances
    async.forEach saved, ((item, done) -> item.save done), next

# Export the Class.
module.exports = conn.model 'itemType', ItemType