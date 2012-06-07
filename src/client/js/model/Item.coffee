define [
  'backbone'
  'model/sockets'
  'model/ItemType'
], (Backbone, sockets, ItemType) ->

  # Client cache of items.
  # Wired to the server through socket.io
  class Items extends Backbone.Collection

    constructor: (@model, @options) ->
      super model, options
      # connect server response callbacks
      sockets.updates.on 'update', @_onUpdate
      sockets.updates.on 'creation', @_onAdd

    # Provide a custom sync method to wire Items to the server.
    # Disabled.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, instance, args) =>
      throw new Error "Unsupported #{method} operation on Items"

    # **private**
    # Callback invoked when a database creation is received.
    #
    # @param className [String] the modified object className
    # @param item [Object] created item.
    _onAdd: (className, item) =>
      return unless className is 'Item'
      # add the created raw item. An event will be triggered
      @add item

    # **private**
    # Callback invoked when a database update is received.
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given item.
    _onUpdate: (className, changes) =>
      return unless className is 'Item'
      # first, get the cached item and quit if not found
      item = @get changes._id
      return unless item?
      # then, update the local cache.
      for key, value of changes
        item.set key, value if key isnt '_id' and key isnt 'type' and key isnt 'map'

      # emit a change.
      @trigger 'update', item


    # Override of the inherited method to disabled default behaviour.
    # DO NOT reset anything on fetch.
    reset: =>


  # Modelisation of a single Item.
  # Not wired to the server : use collections Items instead
  class Item extends Backbone.Model

    # item local cache.
    # A Backbone.Collection subclass that handle Items retrieval with `fetch()`
    @collection = new Items @

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Item constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes 
      # Construct a Map around the raw map.
      if attributes?.map?
        # to avoid circular dependencies
        Map = require('model/Map')
        if typeof attributes.map is 'string'
          # gets by id
          map = Map.collection.get attributes.map
          unless map
            # trick: do not retrieve map, and just construct with empty name.
            @set 'map', new Map {_id: attributes.map}
          else 
            @set 'map', map
        else
          # or construct directly
          @set 'map', new Map attributes.map

      # Construct a Type around the raw map.
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
          @set 'type', new ItemType attributes.type

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

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current item is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  return Item