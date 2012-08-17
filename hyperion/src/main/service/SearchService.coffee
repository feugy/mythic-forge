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
FieldType = require '../model/FieldType'
EventType = require '../model/EventType'
Map = require '../model/Map'
Executable = require '../model/Executable'
utils = require '../utils'
async = require 'async'
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

# Enhance query by making-it Mongo-db compliant:
# - add ObjectId constructor for id search
# - add 'properties.' before arbitrary properties
# - support locale for 'name' and 'desc'
# - check arbitrary property existence
# - transforms 'and'/'or' to '$and'/'$or'
#
# @param query [Object] query that is enhanced
# @param locale [String] desired locale
enhanceQuery = (query, locale) ->
  if Array.isArray query
    # recursive enhancement inside term arrays
    enhanceQuery term for term in query
  else
    attr = Object.keys(query)[0]
    value = query[attr]
    switch attr
      when 'and', 'or'
        query["$#{attr}"] = value
        delete query[attr]
        enhanceQuery value, locale
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
      when 'quantifiable'
         # nothing to do
      else
        # for properties, append the "properties" root
        delete query[attr]
        attr = "properties.#{attr}"
        if value is '!'
          query[attr] = {$exists:1} 
        else 
          query["#{attr}.def"] = value
  
# The SearchService allows to performs search on some attributes of types 
# (ItemType, FieldType, EventType, Map, Executable)
class _SearchService

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
  # @param callback [Function] result callback, invoked with arguments
  # @option callback err [Error] an error, or null if no error occured
  # @option callback results [Array<Object>] array (may be empty) of matching types
  #
  # @overload searchType(query, callback)
  #   Search with default locale
  #   @param query [Object] the search query
  #
  # @overload searchType(query, locale, callback)
  #   Search with specified locale
  #   @param query [Object] the search query
  #   @param locale [String] the desired locale
  searchType: (args..., callback) =>
    switch args.length
      when 1
        query = args[0]
        locale = 'default'
      when 2
        query = args[0]
        locale = args[1]
      else new Error 'searchType() must be call with query and callback, or query, locale and callback'

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
      enhanceQuery query, locale

      # then, perform it on each database collection
      async.forEach [ItemType, EventType, FieldType, Map,], search, (err) =>
        # return aggregated results
        callback null, results

# singleton instance
_instance = undefined
class SearchService
  @get: ->
    _instance ?= new _SearchService()

module.exports = SearchService