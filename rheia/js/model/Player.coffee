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
  'model/BaseModel'
  'model/Item'
  'utils/utilities'
  'model/sockets'
], (Base, Item, utils, sockets) ->

  # Client cache of players.
  # Wired to the server through socket.io
  class _Players extends Base.Collection

    # List of connected players's email. 
    # Read only: automatically updated by _onPlayerEvent.
    # Event `connectedPlayersChanged` is triggered when the list has changed.
    # Newly connected player emails is passed as first parameter, disconnected player emails as second.
    connected: []

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Player'

    # Collection constructor, that wired on events.
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (@model, @options) ->
      super @model, @options
      @connected = []

      sockets.admin.on 'players', @_onPlayerEvent

      # initialize the connected list
      sockets.admin.once 'connectedList-resp', (list) =>
        @connected = list
        @trigger 'connectedPlayersChanged', @connected, []
      sockets.admin.emit 'connectedList'

    # Method to arbitrary kick a user. 
    # No callback, but an event will be received if kick was effective, and the list of connected players will be updated
    #
    # @param email [String] email of kicked player
    kick: (email) =>
      sockets.admin.emit 'kick', email

    # **private**
    # Handler of (dis)connected player account
    # a `connectedPlayersChanged` event is triggered at the end of the list update
    _onPlayerEvent: (event, player) =>
      switch event
        when 'connect'
          @connected.push player.email
          @trigger 'connectedPlayersChanged', [player.email], []
        when 'disconnect'
          idx = @connected.indexOf player.email
          @connected.splice idx, 1 if idx isnt -1
          @trigger 'connectedPlayersChanged', [], [player.email]

  # Player account.
  class Player extends Base.Model

    # Local cache for models.
    @collection: new _Players @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Player'

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Player constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes

      # constructs Items for the corresponding characters
      if attributes?.characters?
        for character, i in attributes.characters
          # we got an object: adds it
          Item.collection.add character
          attributes.characters[i] = Item.collection.get character._id