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
], (Base, Item, utils) ->

  # Enrich player characters from with Backbone Model. 
  # May ask to server the missing characters item.
  # Use a callback or trigger update on enriched model.
  #
  # @param model [Event] enriched model
  # @param callback [Function] end enrichment callback. Default to null.
  enrichCharacters = (model, callback) ->
    callback = if 'function' is utils.type callback then callback else () -> true
    raws = model.characters.concat()
    loaded = []
    doLoad = false
    model.characters = []
    # try to replace all characters by their respective Backbone Model
    for raw in raws
      id = if 'object' is utils.type raw then raw.id else raw
      loaded.push id
      character = Item.collection.get id
      if !(character?) and 'object' is utils.type raw
        character = new Item raw
        Item.collection.add character
      else if !(character?)
        doLoad = true
        character = id
      model.characters.push character
    
    if doLoad
      # load missing characters
      processItems = (err, items) =>
        unless err? or null is _.find(items, (item) -> item.id is loaded[0])
          app.sockets.game.removeListener 'getItems-resp', processItems
          model.characters = []
          # immediately add enriched characters
          for raw in items
            existing = Item.collection.get raw.id
            if existing?
              model.characters.push existing
              # reuse existing but merge its values
              Item.collection.add raw
            else
              # add new character
              character = new Item raw
              Item.collection.add character
              model.characters.push character

          callback()

      app.sockets.game.on 'getItems-resp', processItems
      app.sockets.game.emit 'getItems', loaded
    else
      callback()

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

      utils.onRouterReady =>
        app.sockets.admin.on 'players', @_onPlayerEvent

        # initialize the connected list
        app.sockets.admin.once 'connectedList-resp', (list) =>
          @connected = list
          @trigger 'connectedPlayersChanged', @connected, []
        app.sockets.admin.emit 'connectedList'

    # Method to arbitrary kick a user. 
    # No callback, but an event will be received if kick was effective, and the list of connected players will be updated
    #
    # @param email [String] email of kicked player
    kick: (email) =>
      app.sockets.admin.emit 'kick', email

    # **private**
    # Callback invoked when a database creation is received.
    # Adds the model to the current collection if needed, and fire event 'add'.
    # Extension to resolve characters when needed
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onAdd: (className, model) =>
      return unless className is @_className
      
      # resolves characters object if possible
      if 'characters' of model and Array.isArray model.characters
        # calls inherited merhod
        enrichCharacters model, => super className, model
      else
        # calls inherited merhod
        super className, model

    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    # Extension to resolve characters when needed
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className

      # resolves characters object if possible
      if 'characters' of changes and Array.isArray changes.characters
        enrichCharacters changes, => super className, changes
      else
        # Call inherited merhod
        super className, changes

    # **private**
    # Handler of (dis)connected player account
    # a `connectedPlayersChanged` event is triggered at the end of the list update
    #
    # @param event [String] event name. `connected` and `disconnected` event are handled
    # @param player [Object] player concerned by the event
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

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['email', 'provider', 'lastConnection', 'firstName', 'lastName', 'password', 'isAdmin', 'characters', 'prefs']

    # Player constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      # and now initialize the Player
      super attributes
      if Array.isArray @characters
        # constructs Items for the corresponding characters
        enrichCharacters @

      # update if one of characters item was removed
      app.router.on 'modelChanged', (kind, model) => 
        return unless kind is 'remove' and !@equals model
        modified = false
        @characters = _.filter @characters, (character) -> 
          if model.equals character
            modified = true
            false
          else
            true
        # indicate that model changed
        if modified
          console.log "update player #{@id} after removing a linked characters #{model.id}"
          @trigger 'update', @, characters: @characters

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Extend inherited method to avoid sending from item, to avoid recursion, before returning JSON representation 
    #
    # @return a serialized version of this model
    _serialize: => 
      attrs = super()
      if Array.isArray attrs.characters
        attrs.characters = _.map attrs.characters, (character) -> character?.id
      attrs