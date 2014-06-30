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

_ = require 'underscore'
ItemType = require '../model/ItemType'
FieldType = require '../model/FieldType'
EventType = require '../model/EventType'
Map = require '../model/Map'
Field = require '../model/Field'
Item = require '../model/Item'
Event = require '../model/Event'
Player = require '../model/Player'
Executable = require '../model/Executable'
ClientConf = require '../model/ClientConf'
{type, fromRule} = require '../util/common'
{isValidId} = require '../util/model'
logger = require('../util/logger').getLogger 'service'
playerService = require('./PlayerService').get()
authoringService = require('./AuthoringService').get()
supported = ['Field', 'Item', 'Event', 'Player', 'ClientConf', 'ItemType', 'Executable', 'FieldType', 'Map', 'EventType', 'FSItem']
listSupported = supported[4..]

# The AdminService export administration features.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
class _AdminService

  # Service constructor.
  # Ensure default configuration existence.
  constructor: ->
    ClientConf.findOne {_id:'default'}, (err, result) =>
      throw "Unable to check default configuration existence: #{err}" if err?
      return logger.info '"default" configuration already exists' if result?
      new ClientConf(id: 'default').save (err) =>
        throw "Unable to create \"default\" configuration: #{err}" if err?
        logger.info '"default" client configuration has been created'

  # This simple method indicates wether or not the id is valid and not used.
  #
  # @param id [String] the checked id
  # @option callback err [String] error string. Null if no error occured and id is valid and not used
  isIdValid: (id, callback) =>
    return callback "#{id} is invalid" unless isValidId id
    return callback "#{id} is already used" if ItemType.isUsed id
    callback null

  # The list method retrieve all instances of a given model, in:
  # Map, ItemType, Executable, FieldType, EventType and FSItem (AuthoringService.readRoot()). 
  # Field and items must be retrieved with `GameService.consult()`.
  #
  # @param modelName [String] class name of the listed models
  # @param callback [Function] end callback, invoked with three arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback modelName [String] reminds the listed model class name
  # @option callback models [Array] list (may be empty) of retrieved models
  #
  list: (modelName, callback) =>
    return if fromRule module, callback
    return callback "The #{modelName} model can't be listed", modelName unless modelName in listSupported
    switch modelName
      when 'ItemType' then ItemType.find (err, result) -> callback err, modelName, result
      when 'FieldType' then FieldType.find (err, result) -> callback err, modelName, result
      when 'EventType' then EventType.find (err, result) -> callback err, modelName, result
      when 'Executable' then Executable.find (err, result) -> callback err, modelName, result
      when 'Map' then Map.find (err, result) -> callback err, modelName, result
      when 'ClientConf' then ClientConf.find (err, result) -> callback err, modelName, result
      when 'FSItem' then authoringService.readRoot (err, root) -> callback err, modelName, root.content unless err?

  # Saves an instance of any model.
  #
  # @param modelName [String] class name of the saved model
  # @param values [Object] saved values, used as argument of the model constructor. Array of saved values
  # for fields.
  # @param email [String] email of the connected player, needed for FSItem methods
  # @param callback [Function] end callback, invoked with three arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback modelName [String] reminds the saved model class name
  # @option callback model [Object] saved model
  save: (modelName, values, email, callback) =>
    return if fromRule module, callback
    return callback "The #{modelName} model can't be saved", modelName unless modelName in supported

    _save = (model) ->
      model.save (err, saved) -> callback err, modelName, if modelName is 'Player' then Player.purge saved else saved

    modelClass = null
    switch modelName
      when 'ClientConf' 
        # do not allow unspecified id for client configurations
        values.id = 'default' unless values.id?
        modelClass = ClientConf

      when 'ItemType' then modelClass = ItemType
      when 'EventType' then modelClass = EventType
      when 'FieldType' then modelClass = FieldType
      when 'Executable' then modelClass = Executable
      when 'Map' then modelClass = Map
      when 'Player' then modelClass = Player
      when 'Item' 
        populateTypeAndSave = (model) ->
          # resolve type in db
          ItemType.findCached [model?.type?.id or model?.type], (err, types) ->
            return callback "Failed to save item #{values.id}. Error while resolving its type: #{err}" if err?
            return callback "Failed to save item #{values.id} because there is no type with id #{values?.type?.id}" unless types.length is 1    
            # Do the replacement.
            model.type = types[0]
            _save model

        if 'id' of values and Item.isUsed values.id
          # retreive previous values
          return Item.findCached [values.id], (err, models) ->
            return callback "Unexisting Item with id #{values.id}: #{err}", modelName if err? or models.length is 0
            model = models[0]

            # update values
            for key, value of values
              model[key] = value unless key in ['id', 'type', 'map']

            # update map value
            if model.map?.id isnt (values.map?.id or values.map)
              if values.map?.id or values.map?
                # resolve map
                return Map.findCached [values.map.id or values.map], (err, maps) ->
                  return callback "Failed to save item #{values.id}. Error while resolving its map: #{err}" if err?
                  return callback "Failed to save item #{values.id} because there is no map with id #{item.map}" unless maps.length is 1  
                  model.map = maps[0]
                  populateTypeAndSave model
              else
                model.map = null
                populateTypeAndSave model
            else
              populateTypeAndSave model
        else
          model = new Item values
          return populateTypeAndSave model

      when 'Event' 
        populateTypeAndSave = (model) ->
          EventType.findCached [model?.type?.id or model?.type], (err, types) ->
            return callback "Failed to save event #{values.id}. Error while resolving its type: #{err}" if err?
            return callback "Failed to save event #{values.id} because there is no type with id #{values?.type?.id}" unless types.length is 1    
            # Do the replacement.
            model.type = types[0]
            _save model

        resolveFrom = (model) ->
          if model.from?
            id = if 'object' is type model.from then model.from?.id else model.from
            # resolve from item
            return Item.findCached [id], (err, froms) ->
              return callback "Failed to save event #{values.id}. Error while resolving its from: #{err}" if err?
              return callbacl "Failed to save event #{values.id} because there is no from with id #{id}" unless froms.length is 1  
              model.from = froms[0]
              populateTypeAndSave model
          else
            model.from = null
            populateTypeAndSave model

        if 'id' of values and Event.isUsed values.id
          # resolve type
          return Event.findCached [values.id], (err, models) ->
            return callback "Unexisting Item with id #{values.id}: #{err}", modelName if err? or models.length is 0
            model = models[0]

            # update values
            for key, value of values
              model[key] = value unless key in ['id', 'type']

            # update from value
            resolveFrom model
        else
          model = new Event values
          return resolveFrom model

      when 'Field'
        return callback 'Fields must be saved within an array', modelName unless Array.isArray values
        savedFields = []

        # unqueue last field inside the array
        unqueue = (err, saved) ->
          savedFields.push saved if saved?
          # end of the array: return callback
          return callback err, modelName, savedFields if values.length is 0
          field = values.pop()
          # do not save mongoose details.
          if 'toObject' of field and field.toObject instanceof Function
            field = field.toObject()
          return callback 'Fields cannot be updated', modelName, savedFields if 'id' of field
          new Field(field).save unqueue

        return unqueue null, null 

      when 'FSItem'
        return authoringService.save values, email, (err, saved) -> callback err, modelName, saved

    # do not directly save Mongoose models
    if 'toObject' of values and values.toObject instanceof Function
      values = values.toObject()

    # get existing values if if present and used for classes that support it
    if 'id' of values and (modelName in ['FSItem', 'Field'] or Item.isUsed values.id)
      modelClass.findCached [values.id], (err, models) ->
        return callback "Unexisting #{modelName} with id #{values.id}: #{err}", modelName if err? or models.length is 0
        model = models[0]

        for key, value of values
          model[key] = value unless key in ['id', 'properties']
          # manually set and unset properties
          if key is 'properties'
            # at the begining, all existing properties may be unset
            unset = _(model.properties).keys()
            set = []
            for name, prop of value
              idx = unset.indexOf(name)
              if -1 is idx
                # new property !
                set.push([name, prop.type, prop.def])
              else
                # property already exists: do not unset
                unset.splice idx, 1
                # and update values if necessary
                if model.properties[name].type isnt prop.type or model.properties[name].def isnt prop.def
                  set.push([name, prop.type, prop.def])

            # at last, add new properties
            model.setProperty.apply model, args for args in set
            # and delete removed ones
            model.unsetProperty name for name in unset

        _save model
    else 
      # or save new one
      _save new modelClass values

  # Deletes an instance of any model.
  #
  # @param modelName [String] class name of the saved model
  # @param values [Object] removed values, used as argument of the model constructor. Array of removed values
  # for fields.
  # @param email [String] email of the connected player, needed for FSItem method
  # @param callback [Function] end callback, invoked with three arguments
  # @option callback err [String] error string. Null if no error occured
  # @option callback modelName [String] reminds the saved model class name
  # @option callback model [Object] saved model
  remove: (modelName, values, email, callback) =>
    return if fromRule module, callback
    return callback "The #{modelName} model can't be removed", modelName unless modelName in supported
    unless 'Field' is modelName or 'FSItem' is modelName or 'id' of values
      return callback "Cannot remove #{modelName} because no 'id' specified", modelName 
    modelClass = null
    switch modelName
      when 'ClientConf' then modelClass = ClientConf
      when 'ItemType' then modelClass = ItemType
      when 'EventType' then modelClass = EventType
      when 'FieldType' then modelClass = FieldType
      when 'Executable' then modelClass = Executable
      when 'Map' then modelClass = Map
      when 'Item' then modelClass = Item
      when 'Event' then modelClass = Event
      when 'Player' then modelClass = Player
      when 'Field'
        return callback 'Fields must be removed within an array', modelName unless Array.isArray values
        removedFields = []

        # unqueue last field inside the array
        unqueue = (err) ->
          # end of the array: return callback
          return callback err, modelName, removedFields if values.length is 0
          field = values.pop()
          # find field by id
          Field.findById field.id, (err, model) ->
            return callback "Unexisting field with id #{field.id}", modelName, removedFields if err? or !(model?)
            removedFields.push model
            # and remove it.
            model.remove unqueue

        return unqueue null

      when 'FSItem'
        return authoringService.remove values, email, (err, removed) -> callback err, modelName, removed

    # get existing values
    modelClass.findCached [values.id], (err, models) ->
      return callback "Unexisting #{modelName} with id #{values.id}", modelName if err? or models.length is 0
      # special player case: purge and disconnect before removing
      if modelName is 'Player'
        playerService.disconnect models[0].email, 'removal', (err) ->
          return callback err, modelName if err?
          models[0].remove (err) -> callback err, modelName, Player.purge models[0] 
      else
        # and removes them
        models[0].remove (err) -> callback err, modelName, models[0]

_instance = undefined
class AdminService
  @get: ->
    _instance ?= new _AdminService()

module.exports = AdminService