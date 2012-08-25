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

  # BaseCollection provides common behaviour for model collections.
  #
  # The `sync`method is wired to server Api `list` when reading the collection.
  # Collection will be automatically updated when receiving updates from server, 
  # and relevant events will be fired.
  class BaseCollection extends Backbone.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    # **Must be defined by subclasses**
    _className: null

    # Collection constructor, that wired on events.
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (@model, @options) ->
      super options
      # bind _onGetList response
      sockets.admin.on 'list-resp', @_onGetList

      # bind updates
      sockets.updates.on 'creation', @_onAdd
      sockets.updates.on 'update', @_onUpdate
      sockets.updates.on 'deletion', @_onRemove

    # Provide a custom sync method to wire model to the server.
    # Only read operation is supported.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      throw new Error "Unsupported #{method} operation on #{@_className}" unless method is 'read'
      sockets.admin.emit 'list', @_className

    # **private**
    # Return handler of `list` server method.
    #
    # @param err [String] error message. Null if no error occured
    # @param modelName [String] reminds the listed class name.
    # @param models [Array<Object>] raw models.
    _onGetList: (err, modelName, models) =>
      return unless modelName is @_className
      return rheia.router.trigger 'serverError', err, method:"#{@_className}.collection.sync", details:'read' if err?
      # add returned types in current collection
      @reset models

    # **private**
    # Callback invoked when a database creation is received.
    # Adds the model to the current collection if needed, and fire event 'add'.
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onAdd: (className, model) =>
      return unless className is @_className
      # add the created raw model. An event will be triggered
      @add model
      # propagates changes on collection to global change event
      rheia.router.trigger 'modelChanged'

    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className
      # first, get the cached item type and quit if not found
      model = @get changes._id
      return unless model?
      # then, update the local cache.
      model.set key, value for key, value of changes when key isnt '_id'

      # emit a change.
      @trigger 'update', model, @, changes
      # propagates changes on collection to global change event
      rheia.router.trigger 'modelChanged'

    # **private**
    # Callback invoked when a database deletion is received.
    # Removes the model from the current collection if needed, and fire event 'remove'.
    #
    # @param className [String] the deleted object className
    # @param model [Object] deleted model.
    _onRemove: (className, model) =>
      return unless className is @_className
      # removes the deleted item after enrich it to allow recognition. An event will be triggered
      @remove new @model model 
      # propagates changes on collection to global change event
      rheia.router.trigger 'modelChanged'

  # BaseModel provides common behaviour for model.
  #
  # The `sync` method is wired to server Api `save` and  `remove` when creating, updating and destroying models.
  # i18n fields are supported, with a local specific attribute, and `equals` method is provided
  class BaseModel extends Backbone.Model

    # Local cache for models.
    # **Must be defined by subclasses**
    @collection = null

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # the locale used for i18n fields
    locale: 'default'

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    # **Must be defined by subclasses**
    _className: null

    # **private**
    # List of model attributes that are localized.
    # **May be defined by subclasses**
    _i18nAttributes: []

    # Overrides inherited getter to handle i18n fields.
    #
    # @param attr [String] the retrieved attribute
    # @return the corresponding attribute value
    get: (attr) =>
      return super attr unless attr in @_i18nAttributes
      value = super "_#{attr}"
      if value? then value[@locale] else undefined

    # Overrides inherited setter to handle i18n fields.
    #
    # @param attr [String] the modified attribute
    # @param value [Object] the new attribute value
    set: (attr, value) =>
      if attr in @_i18nAttributes
        attr = "_#{attr}"
        val = @attributes[attr]
        val ||= {}
        val[@locale] = value
        value = val
      super attr, value

    # Provide a custom sync method to wire Types to the server.
    # Only create and delete operations are supported.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      switch method 
        when 'create', 'update' 
          sockets.admin.once 'save-resp', (err) =>
            rheia.router.trigger 'serverError', err, method:"#{@_className}.sync", details:method, id:@id if err?
          sockets.admin.emit 'save', @_className, @toJSON()
        when 'delete' 
          sockets.admin.once 'save-resp', (err) =>
            rheia.router.trigger 'serverError', err, method:"#{@_className}.sync", details:method, id:@id if err?
          sockets.admin.emit 'remove', @_className, @toJSON()
        else throw new Error "Unsupported #{method} operation on #{@_className}"

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current item is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  {
    Collection: BaseCollection
    Model: BaseModel
  }