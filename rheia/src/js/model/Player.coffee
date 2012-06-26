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
  'backbone'
  'model/Item'
], (Backbone, Item) ->

  # Client cache of players.
  # Wired to the server through socket.io
  class Players extends Backbone.Collection

    constructor: (@model, @options) ->
      super model, options

    # Provide a custom sync method to wire Items to the server.
    # Disabled.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, instance, args) =>
      throw new Error "Unsupported #{method} operation on Players"

  # Player account.
  class Player extends Backbone.Model

    # player local cache.
    # A Backbone.Collection subclass
    @collection = new Players @

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Player account login.
    login: null

    # The associated character. Null if no character associated yet.
    character: null

    # Player constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes 
      # constructs an Item for the corresponding character
      if attributes?.character?
        @set 'character', new Item attributes.character


    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current field is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  return Player