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

async = require 'async'
Item = require '../model/Item'
Event = require '../model/Event'
Field = require '../model/Field'
ItemType = require '../model/ItemType'
EventType = require '../model/EventType'
FieldType = require '../model/FieldType'
Executable = require '../model/Executable'
ruleService = require('./RuleService').get()
logger = require('../logger').getLogger 'service'

# The GameService allow all operations needed by the game interface.
# It's a singleton class. The unic instance is retrieved by the `get()` method.
#
class _GameService

  # Retrieve Item/Event/Field types by their ids
  #
  # @param ids [Array<String>] array of ids
  # @param callback [Function] callback executed when types where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback types [Array<ItemType/EventType/FieldType>] list of retrieved types. May be empty.
  getTypes: (ids, callback) =>
    logger.debug "Consult types with ids: #{ids}"
    types = []
    # search in each possible type category
    async.forEach [ItemType, EventType, FieldType], (clazz, next) =>
      clazz.find {_id: {$in: ids}}, (err, docs) =>
        # quit at first error
        return callback err, null if err?
        types = types.concat docs
        next()
    , -> callback null, types

  # Retrieve Items by their ids. Each linked objects are resolved.
  #
  # @param ids [Array<String>] array of ids
  # @param callback [Function] callback executed when items where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback events [Array<Item>] list of retrieved items. May be empty.
  getItems: (ids, callback) =>
    logger.debug "Consult items with ids: #{ids}"
    Item.find {_id: {$in: ids}}, (err, items) ->
      return callback err, null if err?
      Item.getLinked items, callback

  # Retrieve Events by their ids. Each linked objects are resolved.
  #
  # @param ids [Array<String>] array of ids
  # @param callback [Function] callback executed when items where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback events [Array<Event>] list of retrieved events. May be empty.
  getEvents: (ids, callback) =>
    logger.debug "Consult events with ids: #{ids}"
    Event.find {_id: {$in: ids}}, (err, events) ->
      return callback err, null if err?
      Event.getLinked events, callback

  # Retrieve all items that belongs to a map within given coordinates.
  #
  # @param mapId [String] id of the concerned map.
  # @param lowX [Number] abscissa lower bound (included)
  # @param lowY [Number] ordinate lower bound (included)
  # @param upX [Number] abscissa upper bound (included)
  # @param upY [Number] ordinate upper bound (included)  
  # @param callback [Function] callback executed when items where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback items [Array<Item>] list of retrieved items. May be empty
  # @option callback fields [Array<Field>] list of retrieved fields. May be empty
  consultMap: (mapId, lowX, lowY, upX, upY, callback) =>
    unless mapId? and lowX? and lowY? and upX? and upY? and callback?
      return callback 'All parameters are mandatory' 

    logger.debug "Consult map #{mapId} between #{lowX}:#{lowY} and #{upX}:#{upY}"
    # first get the items
    Item.where('map', mapId)
      .where('x').gte(lowX)
      .where('x').lte(upX)
      .where('y').gte(lowY)
      .where('y').lte(upY)
      .exec (err, items) ->
        return callback err, [], [] if err?
        # then gets the fields
        Field.where('mapId', mapId)
          .where('x').gte(lowX)
          .where('x').lte(upX)
          .where('y').gte(lowY)
          .where('y').lte(upY)
          .exec (err, fields) ->
            return callback err, [], [] if err?
            callback null, items, fields

  # Trigger the rule engine resolution
  # 
  # @see {RuleService.resolve}
  resolveRules: =>
    logger.debug 'Trigger rules resolution'
    ruleService.resolve.apply ruleService, arguments

  # Trigger the rule engine execution
  # 
  # @see {RuleService.execute}
  executeRule: =>
    logger.debug 'Trigger rules execution'
    ruleService.execute.apply ruleService, arguments

  # Export client-side rules
  # 
  # @see {RuleService.export}
  importRules: =>
    logger.debug 'Export rules to client'
    ruleService.export.apply ruleService, arguments

  # Returns the executable's content to allow rule execution on client side
  #
  # @param callback [Function] callback executed when executables where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback items [Array<Executable>] list of retrieved executables. May be empty.
  getExecutables: (callback) =>
    logger.debug 'Consult all executables'
    Executable.find callback

_instance = undefined
class GameService
  @get: ->
    _instance ?= new _GameService()

module.exports = GameService