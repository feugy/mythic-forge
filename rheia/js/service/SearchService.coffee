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

define [
  'underscore'
  'utils/utilities'
  'model/Executable'
  'model/ItemType'
  'model/EventType'
  'model/FieldType'
  'model/Item'
  'model/Event'
  'model/Player'
  'model/Map'
], (_, utils, Executable, ItemType, EventType, FieldType, Item, Event, Player, Map) ->

  classesByName = 
    'ItemType': ItemType
    'EventType': EventType
    'FieldType': FieldType
    'Map': Map
    'Event': Event
    'Item': Item
    'Player': Player
    'Executable': Executable

  # Simple utility method that replace regexp value by a text equivalent.
  #
  # @param query [Object] parse query. Directly modified
  parseQuery = (query) ->
    if Array.isArray query
      parseQuery term for term in query
    else 
      key = Object.keys(query)[0]
      value = query[key]
      if key is 'or' or key is 'and'
        parseQuery value
      else if 'regexp' is utils.type value
        # replace regexp by a string equivalent
        query[key] = "/#{value.source}/#{if value.ignoreCase then 'i' else ''}#{if value.multiline then 'm' else ''}"

  # The search service performs search on server side, and dispatch results to corresponding 
  # collections
  #
  # Instanciated as a singleton in `app.searchService` by the Router
  class SearchService
    
    # Service constructor
    constructor: () ->
      # bind to server responses
      app.sockets.admin.on 'searchTypes-resp', @_onSearchTypesResults
      app.sockets.admin.on 'searchInstances-resp', @_onSearchInstancesResults

    # Performs a type search. At the end, triggers a `searchResults` event with error and results in parameter
    # (and false as `instances` second parameter).
    #  
    # @param query [Object] the search query, modelized with objects and arrays.
    searchTypes: (query) ->
      # transforms the object query to JSON string.
      parseQuery query
      query = JSON.stringify query
      console.log "triggers new search on type with query: #{query}"
      app.sockets.admin.emit 'searchTypes', utils.rid(), query
    
    # Performs an instance search. At the end, triggers a `searchResults` event with error and results in parameter
    # (and true as `instances` second parameter).
    #  
    # @param query [Object] the search query, modelized with objects and arrays.
    searchInstances: (query) ->
      # transforms the object query to JSON string.
      parseQuery query
      query = JSON.stringify query
      console.log "triggers new search on instances with query: #{query}"
      app.sockets.admin.emit 'searchInstances', utils.rid(), query

    # **private**
    # Type search results handler. 
    # Parse returned types, dispatch them to their corresponding collection, and trigger the
    # `searchResults` event with parsed models (and false as `instances` second parameter).
    #
    # @param reqId [String] client request id
    # @param err [String] the server error string, null it no error occured
    # @param results [Array] raw representation of searched types
    _onSearchTypesResults: (reqId, err, results) =>
      return app.router.trigger 'searchResults', err, false, [] if err?

      models = []
      for result in results
        modelClass = classesByName[if '_className' of result then result._className else 'Executable']
        # construct the relevant Backbone.Model
        model = new modelClass result
        modelClass.collection.add model
        # keep the parse model for results
        models.push model

      app.router.trigger 'searchResults', null, false, models

    # **private**
    # Type search instances handler. 
    # Parse returned instance, dispatch them to their corresponding collection, and trigger the
    # `searchResults` event with parsed models (and false as `instances` second parameter).
    #
    # @param reqId [String] client request id
    # @param err [String] the server error string, null it no error occured
    # @param results [Array] raw representation of searched instances
    _onSearchInstancesResults: (reqId, err, results) =>
      return app.router.trigger 'searchResults', err, true, [] if err?

      models = []
      for result in results
        # parse returned models
        modelClass = null

        switch result._className
          when 'Item' then modelClass = Item
          when 'Event' then modelClass = Event
          else 
            modelClass = Player

        if modelClass?
          # construct the relevant Backbone.Model
          model = new modelClass result
          modelClass.collection.add model
          # keep the parse model for results
          models.push model

      app.router.trigger 'searchResults', null, true, models