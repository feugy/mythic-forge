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
], (sockets) ->

  # Client cache of item types.
  class ItemTypes extends Backbone.Collection

    # Collection constructor, that wired on events.
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (@model, @options) ->
      super(model, options)
      # bind getTypes response
      sockets.admin.on('list-resp', @_onGetTypes)
      # bind updates
      sockets.updates.on('creation', @_onAdd)
      sockets.updates.on('update', @_onUpdate)
      sockets.updates.on('deletion', @_onRemove)

    # Provide a custom sync method to wire Types to the server.
    # Only read operation is supported.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      throw new Error("Unsupported #{method} operation on Item Types") unless method is 'read'
      sockets.admin.emit('list', 'ItemType')

    # **private**
    # Return handler of `list` server method.
    #
    # @param err [String] error message. Null if no error occured
    # @param modelName [String] reminds the listed class name.
    # @param types [Array<Object>] raw types.
    _onGetTypes: (err, modelName, types) =>
      return unless modelName is 'ItemType'
      return console.error("Failed to fetch types: #{err}") if err?
      # add returned types in current collection
      @reset(types)

    # **private**
    # Callback invoked when a database creation is received.
    # Adds the model to the current collection if needed, and fire event 'add'.
    #
    # @param className [String] the modified object className
    # @param item [Object] created item.
    _onAdd: (className, item) =>
      return unless className is 'ItemType'
      # add the created raw item. An event will be triggered
      @add(item)

    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given item.
    _onUpdate: (className, changes) =>
      return unless className is 'ItemType'
      # first, get the cached item type and quit if not found
      itemType = @get(changes._id)
      return unless itemType?
      # then, update the local cache.
      for key, value of changes
        itemType.set(key, value) if key isnt '_id'

      # emit a change.
      @trigger('update', itemType, @, {index:@indexOf itemType})

    # **private**
    # Callback invoked when a database deletion is received.
    # Removes the model from the current collection if needed, and fire event 'remove'.
    #
    # @param className [String] the deleted object className
    # @param item [Object] deleted item.
    _onRemove: (className, item) =>
      return unless className is 'ItemType'
      # removes the deleted raw item. An event will be triggered
      @remove(item)

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections Items instead
  #
  class ItemType extends Backbone.Model

    # type local cache.
    # A Backbone.Collection subclass that handle types retrieval with `fetch()`
    @collection = new ItemTypes(@)

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # the locale used for i18n fields
    locale: 'default'

    # ItemType constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super(attributes)

    # Overrides inherited getter to handle i18n fields.
    #
    # @param attr [String] the retrieved attribute
    # @return the corresponding attribute value
    get: (attr) =>
      return super(attr) unless attr in ['name', 'desc']
      value = super("_#{attr}")
      if value? then value[@locale] else undefined

    # Overrides inherited setter to handle i18n fields.
    #
    # @param attr [String] the modified attribute
    # @param value [Object] the new attribute value
    set: (attr, value) =>
      if attr in ['name', 'desc']
        attr = "_#{attr}"
        val = @attributes[attr]
        val ||= {}
        val[@locale] = value
        value = val
      super(attr, value)

    # Provide a custom sync method to wire Types to the server.
    # Only create and delete operations are supported.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      switch method 
        when 'create', 'update' then sockets.admin.emit('save', 'ItemType', @toJSON())
        when 'delete' then sockets.admin.emit('remove', 'ItemType', @toJSON())
        else throw new Error("Unsupported #{method} operation on Item Types")

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current item is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  return ItemType