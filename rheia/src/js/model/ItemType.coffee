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
  'backbone',
  'model/sockets'
], (Backbone, sockets) ->

  # Client cache of item types.
  class ItemTypes extends Backbone.Collection

    constructor: (@model, @options) ->
      super model, options
      # bind getTypes response.
      sockets.admin.on 'list-resp', @_onGetTypes

    # Provide a custom sync method to wire Types to the server.
    # Only the read operation is supported.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    #
    sync: (method, collection, args) =>
      throw new Error "Unsupported #{method} operation on Item Types" unless method is 'read'
      sockets.admin.emit 'list', 'ItemType'

    # Return handler of `list` server method.
    #
    # @param err [String] error message. Null if no error occured
    # @param modelName [String] reminds the listed class name.
    # @param types [Array<Object>] raw types.
    #
    _onGetTypes: (err, modelName, types) =>
      return unless modelName is 'ItemType'
      return console.error "Failed to fetch types: #{err}" if err?
      # add returned types in current collection
      @reset types

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections Items instead
  #
  class ItemType extends Backbone.Model

    # type local cache.
    # A Backbone.Collection subclass that handle types retrieval with `fetch()`
    #
    @collection = new ItemTypes @

    # bind the Backbone attribute and the MongoDB attribute
    #
    idAttribute: '_id'

    # ItemType constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    #
    constructor: (attributes) ->
      super attributes

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current item is tested
    # @return true if both object have the samge ids, and false otherwise.
    #
    equals: (other) =>
      @.id is other?.id

  return ItemType