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
Executable = require '../model/Executable'
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
    return callback "The #{modelName} model can't be listed", modelName unless modelName in ['ItemType', 'Executable']
    switch modelName
      when 'ItemType' then ItemType.find (err, result) -> callback err, modelName, result
      when 'Executable' then Executable.find (err, result) -> callback err, modelName, result

  # Saves an instance of any model.
  #
  # @param modelName [String] class name of the saved model
  # @param values [Object] saved values, used as argument of the model constructor
  # @param callback [Function] end callback, invoked with three arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback modelName [String] reminds the saved model class name
  # @option callback model [Object] saved model
  save: (modelName, values, callback) =>
    return callback "The #{modelName} model can't be saved", modelName unless modelName in ['ItemType', 'Executable']
    
    # do not directly save Mongoose models
    if 'toObject' of values and values.toObject instanceof Function
      values = values.toObject()

    _save = (model) ->
      model.save (err, saved) -> callback err, modelName, saved

    modelClass = null
    switch modelName
      when 'ItemType' then modelClass = ItemType
      when 'Executable' 
        # special behaviour for Executables: save only works with new Executbales
        return Executable.findCached values._id, (err, model) ->
          return callback "Id #{values._id} already used", modelName unless model is null
          # create new if not found
          model = new Executable values 
          _save model

    # get existing values
    if '_id' of values
      modelClass.findCached values._id, (err, model) ->
        return callback "Unexisting #{modelName} with id #{values._id}: #{err}", modelName if err? or model is null
        for key, value of values
          model.set key, value unless key is '_id'
        _save model
    else 
      # or save new one
      _save new modelClass values

  # Dedicated save method for Executables. Allow renaming while saving.
  #
  # @param values [Object] saved values, used as argument of the model constructor
  # @param newId [String] executable new name, of null to disabled renaming.
  # @param callback [Function] end callback, invoked with three arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback oldId [String] previous id, in case of renaming
  # @option callback model [Object] saved executable
  saveAndRename: (values, newId, callback) =>
    # checks that executable exists
    previousId = values._id
    Executable.findCached previousId, (err, executable) ->
      return callback "Unexisting Executable with id #{previousId}" if err? or !(executable?)

      _save = (executable) ->
        executable.save (err, saved) -> callback err, previousId, saved

      if newId
        # check that newId is free
        Executable.findCached newId, (err, existing) ->
          return callback "Id #{newId} already used" unless existing is null
          # remove old value
          executable.remove (err) -> 
            # and save new one after changing the id
            _save new Executable {_id: newId, content: values.content}

      else 
        for key, value of values
          executable[key] = value unless key is '_id'
        _save executable

  # Deletes an instance of any model.
  #
  # @param modelName [String] class name of the saved model
  # @param values [Object] saved values, used as argument of the model constructor
  # @param callback [Function] end callback, invoked with three arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback modelName [String] reminds the saved model class name
  # @option callback model [Object] saved model
  remove: (modelName, values, callback) =>
    return callback "The #{modelName} model can't be removed", modelName unless modelName in ['ItemType', 'Executable']
    return callback "Cannot remove #{modelName} because no '_id' specified", modelName unless '_id' of values
    modelClass = null
    switch modelName
      when 'ItemType' then modelClass = ItemType
      when 'Executable' then modelClass = Executable

    # get existing values
    modelClass.findCached values._id, (err, model) ->
      return callback "Unexisting #{modelName} with id #{values._id}", modelName if err? or !(model?)
      # and removes them
      model.remove (err) -> callback err, modelName, model

_instance = undefined
class AdminService
  @get: ->
    _instance ?= new _AdminService()

module.exports = AdminService