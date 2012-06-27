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
Item = require './Item'
modelWatcher = require('./ModelWatcher').get()
logger = require('../logger').getLogger 'model'

# Define the schema for players
PlayerSchema = new mongoose.Schema
  # no password for now.
  login: 
    type: String 
    required: true

  lastConnection: Date
  
  # link to the character.
  character:
    type: {}
    default: -> null # use a function to force instance variable


# Override the equals() method defined in Document, to check correctly the equality between _ids, 
# with their `equals()` method and not with the strict equality operator.
#
# @param other [Object] other object against which the current object is compared
# @return true if both objects have the same _id, false otherwise
PlayerSchema.methods.equals = (object) ->
  @_id.equals object?._id

# We use the post-save middleware to propagate creation and saves.
# But within this function, all instances have lost their "isNew" status
# thus we store that status from the pre-save middleware, to use it in the post-save
# middleware 
wasNew = {}
modifiedPaths = {}

# pre-save middleware: store modified paths to allow their propagation
#
# @param next [Function] function that must be called to proceed with other middleware.
PlayerSchema.pre 'save', (next) ->
  # stores the isNew status.
  wasNew[@_id] = @isNew
  modifiedPaths[@_id] = @modifiedPaths.concat()
  # replace character with its id, for storing in Mongo, without using setters.
  saveCharacter = @character
  @_doc.character = saveCharacter?._id
  next()
  # restore save to allow reference reuse.
  @_doc.character = saveCharacter


# pre-init middleware: retrieve the character corresponding to the stored id.
#
# @param item [Item] the initialized item.
# @param next [Function] function that must be called to proceed with other middleware.
PlayerSchema.pre 'init', (next, player) ->
  return next() unless player.character? 
  # loads the character from database
  Item.findOne {_id: player.character}, (err, character) ->
    return next(new Error "Unable to init item #{player._id}. Error while resolving its character: #{err}") if err?
    return next(new Error "Unable to init item #{player._id} because there is no item with id #{player.character}") unless character?    
    # Do the replacement.
    player.character = character
    next()

# post-save middleware: now that the instance was properly saved, propagate its modifications
PlayerSchema.post 'save', () ->
  modelWatcher.change (if wasNew[@_id] then 'creation' else 'update'), 'Player', this, modifiedPaths[@_id]

# post-remove middleware: now that the instace was properly removed, propagate the removal.
PlayerSchema.post 'remove', () ->
  modelWatcher.change 'deletion', 'Player', this

# Export the Class.
Player = conn.model 'player', PlayerSchema
module.exports = Player