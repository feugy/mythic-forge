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
  'utils/utilities'
  'model/BaseModel'
  'model/ItemType'
], (utils, Base, ItemType) ->

  # Client cache of items.
  class _Items extends Base.LinkedCollection

    # Class of the type of this model.
    @typeClass: ItemType

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Item'

    # **private**
    # List of not upadated attributes
    _notUpdated: ['_id', 'type', 'map']

    # enhanced inheritted method to trigger `add` event on existing models that
    # are added a second time.
    #
    # @param models [Object/Array] added model(s)
    # @param options [Object] addition options
    add: (models, options) =>
      existings = []
      
      models = if Array.isArray models then models else [models]
      # keep existing models that will be merged
      existings.push @_byId[model._id] for model in models when @_byId?[model._id]?
      
      # superclass behaviour
      super models, options
      
      # trigger existing model re-addition
      model.trigger 'add', model, @, options for model in existings

    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    # Extension to resolve map when needed
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className
      if 'map' of changes and changes.map?
        id = if 'object' is utils.type changes.map then changes.map._id else changes.map
        changes.map = require('model/Map').collection.get id

      # manages transition changes
      if 'transition' of changes
        model = @get changes._id
        model._transition = changes.transition if model?

      # Call inherited merhod
      super className, changes

      # reset transition change detection when updated
      if 'transition' of changes
        model = @get changes._id
        model._transitionChanged = false

  # Modelisation of a single Item.
  # Not wired to the server : use collections Items instead
  class Item extends Base.LinkedModel

    # Class of the type of this model.
    @typeClass: ItemType

    # Array of path of classes in which linked objects are searched.
    @linkedCandidateClasses: ['model/Event']

    # Local cache for models.
    # **Caution** must be defined after @linkedCandidateClasses to allow loading 
    @collection: new _Items @

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['map', 'x', 'y', 'imageNum', 'state', 'transition', 'quantity', 'type']

    # **private**
    # Provide the transition used to animate items.
    # Do not use directly used `model.getTransition` because it's not reset when not appliable.
    _transition: null

    # **private**
    # FIXME: for some unknown reason, BAckbone Model does not detect changes on attributes, andwe must
    # detect them manually
    _transitionChanged: false

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Item'

    # Item constructor.
    # Will fetch type from server if necessary, and trigger the 'typeFetched' when finished.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes
      @_transitionChanged = false
      # Construct a Map around the raw map.
      if attributes?.map?
        # to avoid circular dependencies
        Map = require 'model/Map'
        if typeof attributes.map is 'string'
          # gets by id
          map = Map.collection.get attributes.map
          unless map
            # trick: do not retrieve map, and just construct with empty name.
            @map = new Map _id: attributes.map
          else 
            @map = map
        else
          # or construct directly
          map = new Map attributes.map
          Map.collection.add map
          @map = map

    # Overrides inherited setter to handle i18n fields.
    #
    # @param attr [String] the modified attribute
    # @param value [Object] the new attribute value
    # @param options [Object] optionnal set options
    set: (attr, value, options) =>
      super attr, value, options
      @_transitionChanged = true if attr is 'transition'

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Removes transition if no modification detected
    #
    # @return a serialized version of this model
    _serialize: => 
      result = super()
      delete result.transition unless @_transitionChanged
      result

    # Returns the Item's transition. Designed to be used only one time.
    # When restrieved, the transition is reset until its next change.
    #
    # @return the current transition, or null if no transition available.
    getTransition: =>
      transition = @_transition 
      @_transition = null
      transition