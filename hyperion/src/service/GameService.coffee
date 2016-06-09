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
_ = require 'lodash'
Item = require '../model/Item'
Event = require '../model/Event'
Field = require '../model/Field'
ItemType = require '../model/ItemType'
EventType = require '../model/EventType'
FieldType = require '../model/FieldType'
Executable = require '../model/Executable'
ClientConf = require '../model/ClientConf'
Player = require '../model/Player'
playerService = require('./PlayerService').get()

{fromRule, confKey} = require '../util/common'
{sep} = require 'path'
{timer} = require '../util/rule'
ruleService = require('./RuleService').get()
logger = require('../util/logger').getLogger 'service'

port = confKey 'server.bindingPort', confKey 'server.staticPort', process.env.PORT
apiPort = confKey 'server.bindingPort', confKey 'server.apiPort', process.env.PORT
host = confKey 'server.host'

baseUrl = "http://#{host}"
# port 80 must be omitted, to allow images resolution on client side.
baseUrl += ":#{port}" if port isnt 80
apiBaseUrl = "#{if certPath = confKey('ssl.certificate', null)? then 'https' else 'http'}://#{host}:#{apiPort}"

# merge two JSON object by putting into the result object a deep coy of all original attributes
#
# @param result [Object] result of the merge, where original object values will replace exiting values
# @param original [Object] object from which the merge is performed
merge = (result, original) ->
  for attr, value of original
    if !_.isArray(value) and _.isObject value
      result[attr] = {} unless result[attr]?
      merge result[attr], value
    else
      result[attr] = value

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
    return if fromRule callback
    logger.debug "Consult types with ids: #{ids}"
    types = []
    # search in each possible type category
    async.forEach [ItemType, EventType, FieldType], (clazz, next) =>
      clazz.find {_id: $in: ids}, (err, docs) =>
        # quit at first error
        return callback err, null if err?
        types = types.concat docs
        next()
    , -> callback null, types

  # Retrieve Items by their ids.
  # Each linked objects are resolved, but cyclic dependencies are broken.
  #
  # @param ids [Array<String>] array of ids
  # @param callback [Function] callback executed when items where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback events [Array<Item>] list of retrieved items. May be empty.
  getItems: (ids, callback) =>
    return if fromRule callback
    logger.debug "Consult items with ids: #{ids}"
    Item.find {_id: $in: ids}, (err, items) ->
      return callback err, [] if err?
      # break cyclic dependencies, to avoid serialization errors
      Item.fetch items, true, callback

  # Retrieve Events by their ids.
  # Each linked objects are resolved, but cyclic dependencies are broken.
  #
  # @param ids [Array<String>] array of ids
  # @param callback [Function] callback executed when events where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback events [Array<Event>] list of retrieved events. May be empty.
  getEvents: (ids, callback) =>
    return if fromRule callback
    logger.debug "Consult events with ids: #{ids}"
    Event.find {_id: $in: ids}, (err, events) ->
      return callback err, [] if err?
      # break cyclic dependencies, to avoid serialization errors
      Event.fetch events, true, callback

  # Retrieve public information on players from their emails.
  # Data returned are: email, lastConnection, firstName, lastName, and a connected boolean
  #
  # @param emails [Array<String>] list of consulted emails
  # @param callback [Function] callback executed when players where retrieved. Called with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback events [Array<Object>] list of retrieved players (plain objects. May be empty.
  getPlayers: (emails, callback) =>
    return if fromRule callback
    logger.debug "Consult players with emails: #{emails}"
    Player.find {email: $in: emails}, (err, players) ->
      return callback err, [] if err?
      callback null, (for player in players
        player = player.publicFields()
        player.connected = player.email in playerService.connectedList
        player
      )

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
    return if fromRule callback
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
    return if fromRule callback
    logger.debug 'Consult all executables'
    Executable.find callback

  # Returns the game configuration for a given locale, merging default values and local specif values
  #
  # @param base [String] base part of the RIA url. Files will be served under this url. Must not end with '/'
  # @param locale [String] desired locale, null to ask for default
  # @param callback [Function] callback executed when configuration ready. Invoked with parameters:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback conf [Object] computed configuration, in json format.
  getConf: (base, locale, callback) =>
    return if fromRule callback
    # get information that does not change often
    conf =
      separator: sep
      basePath: "#{base}/"
      apiBaseUrl: apiBaseUrl
      imagesUrl: "#{baseUrl}/images/"
      gameUrl: "#{baseUrl}/game"
      gameToken: confKey 'game.token'
      # add timer information
      timer:
        value: timer.current().valueOf()
        paused: timer.stopped

    ids = ['default']
    # add locale
    ids.push locale if locale?
    # add locale without sublocale
    ids.push locale.replace /_\w*$/, '' if locale? and -1 isnt locale.indexOf '_'

    # get default client configuration
    ClientConf.findCached ids, (err, confs) =>
      return callback "Failed to load client configurations: #{err}" if err?
      def = _.find confs, _id:'default'
      result = {}

      # first merge with empty configuration
      merge result, def.values if def?

      confs = _.chain(confs).without(def).sortBy('_id').value()
      # then merge remaining locale specific configurations, ending by sublocales
      merge result, spec.values for spec in confs

      # at last, add default configuration values
      merge result, conf
      # return resulting configuration
      callback null, result

_instance = undefined
class GameService
  @get: ->
    _instance ?= new _GameService()

module.exports = GameService