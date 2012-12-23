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

ItemType = require '../model/ItemType'
Item = require '../model/Item'
FieldType = require '../model/FieldType'
EventType = require '../model/EventType'
Event = require '../model/Event'
Map = require '../model/Map'
Executable = require '../model/Executable'
Player = require '../model/Player'
utils = require '../util/common'
async = require 'async'
_ = require 'underscore'
ObjectId = require('mongodb').BSONPure.ObjectID
logger = require('../logger').getLogger 'service'

# Function that validate the query content, regarding what is possible in `searchType()`
# 
# @param query [Object] the validated query
# @return null if query is syntaxically valid, or an error explaining the syntax invalidity
validateQuery = (query) ->
  if Array.isArray query
    return "arrays must contains at least two terms" if query.length < 2
    # we found an array inside a boolean term
    for term in query
      # validates each term, and exit at first error
      err = validateQuery term
      return err if err?

  else if 'object' is utils.type query
    # we found a term:  `{or: []}`, `{and: []}`, `{toto:1}`, `{toto:''}`, `{toto:true}`, `{toto://}`
    keys = Object.keys query
    return "only one attribute is allowed inside query terms" if keys.length isnt 1
    
    value = query[keys[0]]
    if keys[0] is 'and' or keys[0] is 'or'
      # this is a boolean term: validates inside
      return validateQuery value
    else
      # this is a terminal term, validates value's type
      switch utils.type value
        when 'string', 'number', 'boolean', 'regexp' then return null
        else return "#{keys[0]}:#{value} is not a valid value"
  else
    return "'#{query}' is nor an array, nor an object"

# Enhance query for types by making-it Mongo-db compliant:
# - add ObjectId constructor for id search
# - add 'properties.' before arbitrary properties
# - support locale for 'name' and 'desc'
# - check arbitrary property existence
# - transforms 'and'/'or' to '$and'/'$or'
#
# @param query [Object] query that is enhanced
# @param locale [String] desired locale
enhanceTypeQuery = (query, locale) ->
  if Array.isArray query
    # recursive enhancement inside term arrays
    enhanceTypeQuery term, locale for term in query
  else
    attr = Object.keys(query)[0]
    value = query[attr]
    # special case of regexp strings that must be transformed
    if 'string' is utils.type value
      match = /^\/(.*)\/(i|m)?(i|m)?$/.exec value
      value = new RegExp match[1], match[2], match[3] if match?
    switch attr
      when 'and', 'or'
        query["$#{attr}"] = value
        delete query[attr]
        enhanceTypeQuery value, locale
      when 'id'
        try 
          query._id = new ObjectId query[attr]
        catch exc
          # not a valid ObjectId, put an invalid ObjectId
          query._id = null
        delete query.id
      when 'name', 'desc'
        query["_#{attr}.#{locale}"] = value
        delete query[attr]
      when 'quantifiable', 'kind'
         # nothing to do
      else
        # for properties, append the "properties" root
        delete query[attr]
        attr = "properties.#{attr}"
        if value is '!'
          query[attr] = {$exists:true} 
        else 
          query["#{attr}.def"] = value

# The SearchService allows to performs search on some attributes of types 
# (ItemType, FieldType, EventType, Map, Executable)
class _SearchService


  # Enhance query for instances by making-it Mongo-db compliant:
  # - add ObjectId constructor for id search and map/type attributes
  # - support search on map/type attributes : 'map.kind', 'type.name', etc...
  # - transforms 'and'/'or' to '$and'/'$or'
  #
  # @param query [Object] query that is enhanced
  # @param locale [String] desired locale
  # @param callback [Function] callback invoked when query has been enhanced
  # @option callback err [String] error string, or null if no error occured
  _enhanceInstanceQuery: (query, locale, callback) =>
    if Array.isArray query
      # recursive enhancement inside term arrays
      return async.forEachSeries query, (term, next) =>
        @_enhanceInstanceQuery term, locale, next
      , callback
    else
      attr = Object.keys(query)[0]
      value = query[attr]
      # special case of regexp strings that must be transformed
      if 'string' is utils.type value
        match = /^\/(.*)\/(i|m)?(i|m)?$/.exec value
        query[attr] = new RegExp match[1], match[2], match[3] if match?

      switch attr
        when 'and', 'or'
          delete query[attr]
          query["$#{attr}"] = value
          return @_enhanceInstanceQuery value, locale, callback
        when 'id', 'map', 'type', 'from', 'characters'

          if value is '!' and attr isnt 'characters'
            value = {$exists:true}
          else if value is '!'
            value = {$elemMatch: {$exists:true}}
          else
            try 
              value = new ObjectId query[attr]
            catch exc
              # not a valid ObjectId, put an invalid ObjectId
              value = null

          if attr is 'id'
            delete query.id
            query._id = value
          else 
            query[attr] = value
        else
          # manage existing value
          if value is '!' and !attr.match /^\w*\./
            query[attr] = {$ne:null} 

          if !(attr.match /^prefs\./) and attr.match /^\w*\./
            # search on link fields, maps, from, type...: we must first get ids with a sub query
            subQuery = {}
            match = attr.match /^(\w*)\.(.*)$/
            subQuery[match[2]] = query[attr]
            delete query[attr]
            if match[1] is 'map' or match[1] is 'type'
              # map and type: search in types
              return @searchTypes subQuery, locale, (err, results) =>
                return callback err if err?
                # then we can search instance of a given map/type ids
                query[match[1]] = {$in:_.pluck(results, '_id')}
                callback null
            else
              # others: search in instances
              return @searchInstances subQuery, locale, (err, results) =>
                return callback err if err?
                # then we can search instance linked to given ids (stored as strings, unless for from and characters)
                ids = if match[1] in ['from', 'characters'] then _.pluck(results, '_id') else _.chain(results).pluck('_id').invoke('toString').value()
                query[match[1]] = {$in:ids}
                callback null

    # everything was fine.
    callback null

  # Performs a type search. 
  # A search is an array of tokens, organized with 'and' and 'or' boolean operators within objects ('and' has precedence above 'or').
  # for example: 
  # - 1 -> 1
  # - 1 or 2 -> {or: [1, 2]}
  # - 1 or 2 or 3 -> {or: [1, 2, 3]}
  # - 1 and 2 or 3 -> [{or: [{and: [1, 2]}, 3]
  # - 1 and (2 or 3) -> [{and: [1, {or: [2, 3]}]
  #
  # Allows the following token:
  # - `id:*val*` search by id, *val* is a string (item, event, field, map, rule, turn-rule)
  # - `name:*val*` search in name (depending the locale), *val* is a string or a regexp (item, event, field, map, rule, turn-rule)
  # - `desc:*val*` search in description (depending the locale), *val* is a string or a regexp (item, event, field)
  # - `*prop*:'!'` search property existence, *prop* is a string (item, event)
  # - `*prop*:*val*` search property default value, *prop* is a string, *val* is a string, number, boolean or regexp (item, event)
  # - `quantifiable:*val*` search quantifiable status, *val* is true|false (item)
  # - `category:*val*` search in categories, *val* is a string or a regexp (rule, turn-rule)
  # - `rank:*val*` search by order, *val* is an integer (turn-rule)
  # - `content:*val*` search in file content, *val* is a string or a regexp (rule, turn-rule)
  #
  # @param query [Object|String] the search query. In case of a string, must be a JSON compliant string.
  # Regexp values are supported: "/.*/i" will be parsed into /.*/i
  # @param callback [Function] result callback, invoked with arguments
  # @option callback err [Error] an error, or null if no error occured
  # @option callback results [Array<Object>] array (may be empty) of matching types
  #
  # @overload searchType(query, callback)
  #   Search with default locale
  #
  # @overload searchType(query, locale, callback)
  #   Search with specified locale
  #   @param locale [String] the desired locale
  searchTypes: (args..., callback) =>
    switch args.length
      when 1
        query = args[0]
        locale = 'default'
      when 2
        query = args[0]
        locale = args[1]
      else new Error 'searchType() must be call with query and callback, or query, locale and callback'

    # special case: string query must be parse to object
    if 'string' is utils.type query
      try 
        query = JSON.parse query
      catch exc
        return callback "Failed to parse query: #{exc}" 

    # first, validate query syntax
    err = validateQuery query
    return callback "Failed to parse query: #{err}" if err?

    results = []
    # second, define a search function on a single database collection
    search = (collection, next) =>
      collection.find query, (err, collResults) =>
        return callback "Failed to execute query: #{err}" if err?
        results = results.concat collResults
        next()

    # third, trigger search inside Executables
    search Executable, =>

      # fourth, enhance the query for mongoDB
      enhanceTypeQuery query, locale

      # then, perform it on each database collection
      async.forEach [ItemType, EventType, FieldType, Map], search, (err) =>
        # return aggregated results
        callback null, results

  # Performs an instance search. 
  # A search is an array of tokens, organized with 'and' and 'or' boolean operators within objects ('and' has precedence above 'or').
  # for example: 
  # - 1 -> 1
  # - 1 or 2 -> {or: [1, 2]}
  # - 1 or 2 or 3 -> {or: [1, 2, 3]}
  # - 1 and 2 or 3 -> [{or: [{and: [1, 2]}, 3]
  # - 1 and (2 or 3) -> [{and: [1, {or: [2, 3]}]
  #
  # Allows the following token:
  # - `id:*val*` search by id, *val* is a string (item, event, player)
  # - `*prop*:'!'` search property existence, *prop* is a string (item, event)
  # - `*prop*:*val*` search property value, *prop* is a string, *val* is a string, number, boolean, regexp or id string (item, event)
  # - `*prop*.*subprop*:'!'` search linked property where subprop exists. *prop*/*subprop* are strings (item, event)
  # - `*prop*.*subprop*:*val*` search linked property where subprop as a given value. *prop*/*subprop* are strings, *val* is a string, number, boolean or regexp (item, event)
  # - `type:*val*` search type by id, *val* is a string (item, event)
  # - `type.*prop*:*val*` search type where property as a given value. *prop* is a string,*val* is a string, number, boolean, regexp or id string (item, event)
  # - `map:'!'` search by map existence (item)
  # - `map:*val*` search map by id, *val* is a string (item)
  # - `map.*prop*:*val*` search map where property as a given value. *prop* is a string,*val* is a string, number, boolean, regexp or id string (item)
  # - `quantity:*val*` search quantity, *val* is a number (item)
  # - `characters:'!'` search by characters existence (player)
  # - `characters:*val*` search characters by id, *val* is a string (player)
  # - `characters.*prop*:*val*` search characters where property as a given value. *prop* is a string,*val* is a string, number, boolean, regexp or id string (player)
  # - `provider:*val*` search by provider, *val* is a string, regexp or '!' (check existence) (player)
  # - `email:*val*` search by email, *val* is a string or regexp (player)
  # - `firstName:*val*` search by firstName, *val* is a string or regexp (player)
  # - `lastName:*val*` search by lastName, *val* is a string or regexp (player)
  # - `prefs.*path*:*val*` search by preference content, where *path* is a json string path and *val* is anything (player)
  #
  # @param query [Object|String] the search query. In case of a string, must be a JSON compliant string.
  # Regexp values are supported: "/.*/i" will be parsed into /.*/i
  # @param callback [Function] result callback, invoked with arguments
  # @option callback err [Error] an error, or null if no error occured
  # @option callback results [Array<Object>] array (may be empty) of matching instances
  #
  # @overload searchInstances(query, callback)
  #   Search with default locale
  #
  # @overload searchInstances(query, locale, callback)
  #   Search with specified locale
  #   @param locale [String] the desired locale
  searchInstances: (args..., callback) =>
    switch args.length
      when 1
        query = args[0]
        locale = 'default'
      when 2
        query = args[0]
        locale = args[1]
      else new Error 'searchInstances() must be call with query and callback, or query, locale and callback'

    # special case: string query must be parse to object
    if 'string' is utils.type query
      try 
        query = JSON.parse query
      catch exc
        return callback "Failed to parse query: #{exc}" 

    # first, validate query syntax
    err = validateQuery query
    return callback "Failed to parse query: #{err}" if err?

    results = []

    # second, enhance the query for mongoDB
    @_enhanceInstanceQuery query, locale, (err) =>
      return callback "Failed to enhance query: #{err}" if err?

      # third, perform it on each database collection
      async.forEach [Item, Event, Player], (collection, next) =>
        # search function on a single database collection
        collection.find query, (err, collResults) =>
          return next "Failed to execute query: #{err}" if err?
          results = results.concat collResults
          next()
      , (err) =>
        # return aggregated results
        return callback err if err?
        callback null, results

# singleton instance
_instance = undefined
class SearchService
  @get: ->
    _instance ?= new _SearchService()

module.exports = SearchService