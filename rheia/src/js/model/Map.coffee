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

define [
  'model/sockets'
  './Field'
  './Item'
], (sockets, Field, Item) ->

  # Client cache of maps.
  class Maps extends Backbone.Collection

    constructor: (@model, @options) ->
      super(model, options)
      
    # Provide a custom sync method to wire Types to the server.
    # Disabled
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      throw new Error("Unsupported #{method} operation on Maps")

    # Override of the inherited method to disabled default behaviour.
    # DO NOT reset anything on fetch.
    reset: () =>

  # Modelisation of a single Map.
  # Not wired to the server : use collections Maps instead
  class Map extends Backbone.Model

    # type local cache.
    # A Backbone.Collection subclass that handle maps cache
    @collection = new Maps(@)

    # **private**
    # flag to avoid multiple concurrent server call.
    _consultRunning: false

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Map constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super(attributes)
      # connect server response callbacks
      sockets.game.on('consultMap-resp', @_onConsult)

    # Allows to retrieve items and fields on this map by coordinates, in a given rectangle.
    #
    # @param low [Object] lower-left coordinates of the rectangle
    # @option args low x [Number] abscissa lower bound (included)
    # @option args low y [Number] ordinate lower bound (included)
    # @param up [Object] upper-right coordinates of the rectangle
    # @option args up x [Number] abscissa upper bound (included)
    # @option args up y [Number] ordinate upper bound (included)  
    consult: (low, up) =>
      return if @_consultRunning
      @_consultRunning = true
      console.log("Consult map #{@get 'name'} between #{low.x}:#{low.y} and #{up.x}:#{up.y}")
      # emit the message on the socket.
      sockets.game.emit('consultMap', @id, low.x, low.y, up.x, up.y)

    # **private**
    # Return callback of consultMap server operation.
    #
    # @param err [String] error string. null if no error occured
    # @param items [Array<Item>] array (may be empty) of concerned items.
    # @param fields [Array<Field>] array (may be empty) of concerned fields.
    _onConsult: (err, items, fields) =>
      if @_consultRunning
        @_consultRunning = false
        return console.error("Fail to retrieve map content: #{err}") if err?
        # add them to the collection (Item model will be created)
        console.log("#{items.length} map item(s) received #{@get 'name'}")
        Item.collection.add(items)
        console.log("#{fields.length} map item(s) received on #{@get 'name'}")
        Field.collection.add(fields)

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current map is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  return Map