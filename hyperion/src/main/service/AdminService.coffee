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

ItemType = require '../model/ItemType'
logger = require('../logger').getLogger 'service'

# The AdminService export administration features.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
class _AdminService

  # The list method retrieve all instances of a given model
  #
  # @param modelName [String] class name of the listed models
  # @param callback [Function] end callback, invoked with three arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback modelName [String] reminds the listed model class name
  # @option callback models [Array] list (may be empty) of retrieved models
  list: (modelName, callback) =>
    return callback "The #{modelName} model can't be listed", modelName unless modelName in ['ItemType']
    switch modelName
      when 'ItemType' then ItemType.find (err, result) -> callback err, modelName, result

  # Saves an instance of any model.
  #
  # @param modelName [String] class name of the saved model
  # @param values [Object] saved values, used as argument of the model constructor
  # @param callback [Function] end callback, invoked with three arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback modelName [String] reminds the saved model class name
  # @option callback model [Object] saved model
  save: (modelName, values, callback) =>
    return callback "The #{modelName} model can't be saved", modelName unless modelName in ['ItemType']
    modelClass = null
    switch modelName
      when 'ItemType' then modelClass = ItemType

    # do not directly save Mongoose models
    if 'toObject' of values and values.toObject instanceof Function
      values = values.toObject()

    _save = (model) ->
      model.save (err, saved) -> callback err, modelName, saved

    # get existing values
    if '_id' of values
      modelClass.findById values._id, (err, model) ->
        return callback "Unexisting #{modelName} with id #{values._id}: #{err}", modelName if err?
        for key, value of values
          model.set key, value unless key is '_id'
        _save model
    else 
      # or save new one
      _save new ItemType values

  # Deletes an instance of any model.
  #
  # @param modelName [String] class name of the saved model
  # @param values [Object] saved values, used as argument of the model constructor
  # @param callback [Function] end callback, invoked with three arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback modelName [String] reminds the saved model class name
  # @option callback model [Object] saved model
  remove: (modelName, values, callback) =>
    return callback "The #{modelName} model can't be removed", modelName unless modelName in ['ItemType']
    return callback "Cannot remove #{modelName} because no '_id' specified", modelName unless '_id' of values
    modelClass = null
    switch modelName
      when 'ItemType' then modelClass = ItemType

    # get existing values
    modelClass.findById values._id, (err, model) ->
      return callback "Unexisting #{modelName} with id #{values._id}", modelName if err? or !(model?)
      # and removes them
      model.remove (err) -> callback err, modelName, model

_instance = undefined
class AdminService
  @get: ->
    _instance ?= new _AdminService()

module.exports = AdminService