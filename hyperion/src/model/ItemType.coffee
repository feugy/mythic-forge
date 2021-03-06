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

async = require 'async'
typeFactory = require './typeFactory'
conn = require './connection'
logger = require('../util/logger').getLogger 'model'
Item = require './Item'
modelUtils = require '../util/model'

# Define the schema for map item types
ItemType = typeFactory 'ItemType',

  # descriptive image for this type.
  descImage:
    type: String

  # items can have a quantity attribute or not.
  quantifiable:
    type: Boolean
    default: false

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
  #     # The sprite row in the sprite sheet.
  #     rank: {type:Number, default: 0}
  images: 
    type: []
    default: -> []
, 
  typeProperties: true
  instanceClass: 'Item'
  hasImages: true
  middlewares:

    # update items quantity when quantifiable state changes
    # add a name key inside default configuration if instance is new
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    save: (next) ->
      if @isModified 'quantifiable'
        quantity = if @get('quantifiable') then 0 else null
        # save type
        next()
        # get type instances
        Item.find {type: @id}, (err, instances) =>
          return next new Error "Failed to update type instances: #{err}" if err?
          # save all the modified instances
          async.forEach instances, (instance, done) -> 
            logger.debug "set quantity for #{instance.id}: #{quantity}"
            instance.quantity = quantity 
            instance.save done
          , (err) ->
            logger.error "failed to change item quantity: #{err}" if err?
      else
        # save type
        next()

# Export the Class.
module.exports = conn.model 'itemType', ItemType