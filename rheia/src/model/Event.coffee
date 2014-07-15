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

define [
  'utils/utilities'
  'model/BaseModel'
  'model/EventType'
], (utils, Base, EventType) ->

  # Enrich event from with Backbone Model. 
  # May ask to server the missing from item.
  # Use a callback or trigger update on enriched model.
  #
  # @param model [Event] enriched model
  # @param callback [Function] end enrichment callback. Default to null.
  enrichFrom = (model, callback) ->
    callback = if 'function' is utils.type callback then callback else () -> true
    raw = model.from
    id = if 'object' is utils.type raw then raw.id else raw
    require ['model/Item'], (Item) => 
      model.from = Item.collection.get id
      return callback() if model.from?
      if 'object' is utils.type raw
        model.from = new Item raw
        Item.collection.add model.from
        callback()
      else
        rid = utils.rid()
        # load missing from
        processFrom = (reqId, err, froms) =>
          return unless reqId is rid
          app.sockets.game.removeListener 'getItems-resp', processFrom

          return callback() if err?
          raw = _.find(froms, (from) -> from.id is id)
          return callback() unless raw?

          existing = Item.collection.get raw.id
          if existing?
            model.from = existing
            # reuse existing but merge its values
            Item.collection.add raw
          else
            # immediately add enriched from
            model.from = new Item raw
            Item.collection.add model.from
          callback()

        app.sockets.game.on 'getItems-resp', processFrom
        app.sockets.game.emit 'getItems', rid, [id]

  # Client cache of events.
  class _Events extends Base.LinkedCollection

    # Class of the type of this model.
    @typeClass: EventType

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Event'

    # **private**
    # List of not upadated attributes
    _notUpdated: ['id', 'type']

    # **private**
    # Callback invoked when a database creation is received.
    # Adds the model to the current collection if needed, and fire event 'add'.
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onAdd: (className, model) =>
      return unless className is @_className
      
      # resolves from object if possible
      if 'from' of model and model.from?
        # calls inherited merhod
        enrichFrom model, => super className, model
      else
        # calls inherited merhod
        super className, model

    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    # Extension to resolve from when needed
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className

      # resolves from object if possible
      if 'from' of changes and changes.from?
        # calls inherited merhod
        enrichFrom changes, => super className, changes
      else
        # calls inherited merhod
        super className, changes

  # Modelisation of a single Event.
  # Not wired to the server : use collections Events instead
  class Event extends Base.LinkedModel

    # Class of the type of this model.
    @typeClass: EventType

    # Array of path of classes in which linked objects are searched.
    @linkedCandidateClasses: ['model/Item']

    # Local cache for models.
    # **Caution** must be defined after @linkedCandidateClasses to allow loading
    @collection: new _Events @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Event'

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['created', 'updated', 'from', 'type']

    # Event constructor.
    # Enriched from object with Item model. 
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes
      if @from?
        enrichFrom @, => @trigger 'update', @, from: @from

      # update if from item was removed
      app.router.on 'modelChanged', (kind, model) => 
        if kind is 'remove' and @from?.equals model
          console.log "update event #{@id} after removing its from #{model.id}"
          @from = null
          @trigger 'update', @, from: null

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Extend inherited method to avoid sending from item, to avoid recursion, before returning JSON representation 
    #
    # @return a serialized version of this model
    _serialize: => 
      attrs = super()
      attrs.from = attrs.from?.id or null
      attrs.type = attrs.type?.id or attrs.type 
      attrs