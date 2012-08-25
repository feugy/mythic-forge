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
  'model/sockets'
], (Base, sockets) ->

  # Client cache of FSItems.
  class _FSItems extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'FSItem'
      
    # Collection constructor, that wired on events.
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (model, @options) ->
      super model, options
      # bind consultation response
      sockets.admin.on 'read-resp', @_onRead

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
      return sockets.admin.emit 'list', 'FSItem' unless item?
      # Or read the item
      return sockets.admin.emit 'read', item.toJSON()

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
    # Enhanced to dencode file content from base64.
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onAdd: (className, model) =>
      return unless className is @_className
      # transforms from base64 to utf8 string
      model.content = atob model.content unless model.isFolder or model.content is null
      super className, model

    # **private**
    # Enhanced to dencode file content from base64.
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className
      # transforms from base64 to utf8 string
      changes.content = atob changes.content unless changes.isFolder or changes.content is null
      super className, changes

  # Modelisation of a single File System Item.
  class FSItem extends Base.Model

    # FSItem local cache.
    # A Backbone.Collection subclass
    @collection: new _FSItems @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'FSItem'

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

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Enhanced to encode in base64 file content.
    #
    # @return a serialized version of this model
    _serialize: => 
      raw = super()
      # transforms from utf8 to base64 string
      raw.content = btoa raw.content unless raw.isFolder or raw.content is null
      raw