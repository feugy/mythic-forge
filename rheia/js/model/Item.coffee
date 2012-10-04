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
  'model/sockets'
  'model/BaseModel'
  'model/ItemType'
], (sockets, Base, ItemType) ->

  # Client cache of item types.
  class _Items extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Item'

    # **private**
    # List of not upadated attributes
    _notUpdated: ['_id', 'type', 'map']

    # Enhance Backone method to allow existing modesl to be re-added.
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
      if 'map' of changes and changes.map?._id
        changes.map = require('model/Map').collection.get changes.map._id
      # Call inherited merhod
      super className, changes

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections ItemTypes instead
  #
  class Item extends Base.Model

    # Local cache for models.
    @collection: new _Items @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Item'

    # Item constructor.
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

      # Construct an ItemType around the raw type.
      if attributes?.type?
        if typeof attributes.type is 'string'
          # resolve by id
          type = ItemType.collection.get attributes.type
          # not found on client: get it from server
          unless type?
            ItemType.collection.on 'add', @_onTypeFetched
            ItemType.collection.fetch attributes.type
          else 
            @set 'type', type
        else 
          # contruct with all data.
          type = new ItemType attributes.type
          ItemType.collection.add type
          @set 'type', type

    # Handler of type retrieval. Updates the current type with last values
    #
    # @param type [ItemType] an added type.      
    _onTypeFetched: (type) =>
      if type.id is @get 'type'
        console.log "type #{type.id} successfully fetched from server for item #{@id}"
        # remove handler
        ItemType.collection.off 'add', @_onTypeFetched
        # update the type object
        @set 'type', type

    # This method retrieves linked Item in properties.
    # All `object` and `array` properties are resolved. 
    # Properties that aims at unexisting items are reset to null.
    #
    # @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
    # @option callback err [String] an error message if an error occured.
    # @option callback item [Item] the root item on which linked items were resolved.
    resolve: (callback) =>
      needResolution = false
      # identify each linked properties 
      console.log "search linked ids in item #{@id}"
      # gets the corresponding properties definitions
      properties = @get('type').get 'properties'
      for prop, def of properties
        value = @get prop
        if def.type is 'object' and typeof value is 'string'
          # Do not resolve objects that were previously resolved
          needResolution = true
          break
        else if def.type is 'array' and value?.length > 0 and typeof value[0] is 'string'
          # Do not resolve arrays that were previously resolved
          needResolution = true
          break
      
      # exit immediately if no resolution needed  
      return callback null, @ unless needResolution

      # now that we have the linked ids, get the corresponding items.
      sockets.game.once 'getItems-resp', (err, items) =>
        return callback "Unable to resolve linked on #{@id}. Error while retrieving linked: #{err}" if err?
        # silentely update local cache
        idx = @collection.indexOf @
        @collection.add items[0], at:idx, silent: true
        # end of resolution.
        console.log "linked ids for item #{@id} resolved"
        callback null, items[0]

      sockets.game.send 'getItems', [@id]