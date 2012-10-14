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

    # Enhance Backone method to allow existing models to be re-added.
    # Needed because map will add retrieved items when content returned from server, and `add` event needs
    # to be fired from collection
    add: (added, options) =>
      added = [added] unless Array.isArray added
      # silentely removes existing models to allow map to be updated
      for obj in added
        existing = @get obj._id
        continue unless existing?
        @remove existing, silent: true

      super added, options

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

      # Call inherited merhod
      super className, changes

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
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Item'

    # Item constructor.
    # Will fetch type from server if necessary, and trigger the 'typeFetched' when finished.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes
      # Construct a Map around the raw map.
      if attributes?.map?
        # to avoid circular dependencies
        Map = require 'model/Map'
        if typeof attributes.map is 'string'
          # gets by id
          map = Map.collection.get attributes.map
          unless map
            # trick: do not retrieve map, and just construct with empty name.
            @set 'map', new Map _id: attributes.map
          else 
            @set 'map', map
        else
          # or construct directly
          map = new Map attributes.map
          Map.collection.add map
          @set 'map', map