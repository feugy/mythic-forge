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
  'backbone'
  'model/sockets'
], (Backbone, sockets) ->

  # Client cache of FSItems.
  # Wired to the server through socket.io
  class _FSItems extends Backbone.Collection

    constructor: (@model, @options) ->
      super options
      # bind consultation response
      sockets.admin.on 'getRootFSItem-resp', @_onRead
      sockets.admin.on 'readFSItem-resp', @_onRead

      # connect server response callbacks
      #sockets.updates.on('update', @_onUpdate)
      #sockets.updates.on('creation', @_onAdd)
      #sockets.updates.on('deletion', @_onRemove)

    # Provide a custom sync method to wire FSItems to the server.
    # Only read operation allowed.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments. May content:
    # @options item [FSItem] the read FSItem. If undefined, read root
    sync: (method, collection, args) =>
      throw new Error "Unsupported #{method} operation on Items" unless 'read' is method
      item = args?.item
      # Ask for the root content if no item specified
      return sockets.admin.emit 'getRootFSItem' unless item?
      # Or read the item
      return sockets.admin.emit 'readFSItem', item.toJSON()

    # **private**
    # End of a FSItem content retrieval. For a folder, adds its content. For a file, triggers an update.
    #
    # @param err [String] an error message, or null if no error occured
    # @param rawItem [Object] the raw FSItem, populated with its content
    _onRead: (err, rawItem) =>
      return rheia.router.trigger 'serverError', err, method:"FSItem.collection.sync", details:'read' if err?
      if rawItem.isFolder
        # add all folder content inside collection
        @add rawItem.content
        
        # replace raw content by models
        rawItem.content[i] = @get subItem.path for subItem, i in rawItem.content

        # insert folder to allow further update
        item = @get rawItem.path
        @add rawItem unless item?

      # trigger update 
      @_onUpdate 'FSItem', rawItem

    # **private**
    # Callback invoked when a database creation is received.
    #
    # @param className [String] the modified object className
    # @param item [Object] created item.
    _onAdd: (className, item) =>
      return unless className is 'FSItem'
      # add the created raw item. An event will be triggered
      @add item

    # **private**
    # Callback invoked when a database update is received.
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given FSItem.
    _onUpdate: (className, changes) =>
      return unless className is 'FSItem'
      # first, get the cached FSItem and quit if not found
      fsitem = @get changes.path
      return unless fsitem?
      # then, update the local cache.
      fsitem.set key, value for key, value of changes

      # emit a change.
      @trigger 'update', fsitem


    # Override of the inherited method to disabled default behaviour.
    # DO NOT reset anything on fetch.
    reset: =>

  # Modelisation of a single File System Item.
  # Not wired to the server : use collection FSItems instead
  class FSItem extends Backbone.Model

    # FSItem local cache.
    # A Backbone.Collection subclass
    @collection: new _FSItems @

    # bind the Backbone attribute to the path name
    idAttribute: 'path'

    # File extension, if relevant
    extension: ''

    # FSItem constructor.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      super attributes
      # update file extension
      @extension = @get('path').substring @get('path').lastIndexOf('.')+1 unless @get 'isFolder'

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current item is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id