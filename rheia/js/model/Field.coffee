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
  'underscore'
  'backbone'
  'utils/utilities'
], (_, Backbone, utils) ->

  # Field collection to handle multiple operaions on fields.
  # Do not provide any local cache, nor allows field retrival. Use `Map.consult()` method instead.
  # Wired to server changes events.
  class _Fields extends Backbone.Collection

    # Collection constructor, that wired on events.
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (@model, @options) ->
      super options
      # bind updates
      utils.onRouterReady =>
        rheia.sockets.updates.on 'creation', @_onAdd
        rheia.sockets.updates.on 'deletion', @_onRemove

    # Allow multiple saves on fields. Update is not permitted.
    #
    # @param fields [Array<Field>] saved fields
    save: (fields) =>
      rheia.sockets.admin.once 'save-resp', (err) =>
        rheia.router.trigger 'serverError', err, method:'Fields.save', arg:fields if err?
      fields[i] = field.toJSON() for field, i in fields
      rheia.sockets.admin.emit 'save', 'Field', fields

    # Allow multiple removes on fields
    #
    # @param fields [Array<Field>] removed fields
    destroy: (fields) =>
      rheia.sockets.admin.once 'remove-resp', (err) =>
        rheia.router.trigger 'serverError', err, method:'Fields.remove', arg:fields if err?
      fields[i] = field.toJSON() for field, i in fields
      rheia.sockets.admin.emit 'remove', 'Field', fields

    # Provide a custom sync method to wire model to the server.
    # No operation supported.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      throw new Error "Unsupported #{method} operation on #{@_className}"

    # Extends the inherited method to unstore added models.
    # Storing fields is a nonsense in Rheia because no browser action will occur on Fields.
    # Unstoring them will save some memory for other usage
    #
    # @param models [Array|Object] added model, or added array of models
    # @param options [Object] optional arguments, like silent
    add: (models, options) =>
      # calls the inherited method
      super models, options
      models = if _.isArray models then models.slice() else [models]
      for model in models
        @_removeReference @_byId[model._id]
      # deletes local caching
      @models = []
      @_byCid = {}
      @_byId = {}
      length = 0
      return @


    # Override the inherited method to trigger remove events.
    #
    # @param models [Array|Object] removed model, or removed array of models
    # @param options [Object] optional arguments, like silent
    remove: (models, options) =>
      # manually trigger remove events
      models = if _.isArray models then models.slice() else [models]
      @trigger 'remove', @_prepareModel(model, options), @, options for model in models

    # **private**
    # Callback invoked when a database creation is received.
    # Fire event 'add'.
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onAdd: (className, model) =>
      return unless className is 'Field'
      # only to trigger add event
      @add model

    # **private**
    # Callback invoked when a database deletion is received.
    # Fire event 'remove'.
    #
    # @param className [String] the deleted object className
    # @param model [Object] deleted model.
    _onRemove: (className, model) =>
      # only to trigger add event
      @remove new @model model

  # Field model class. Allow creation and removal. Update is not permitted.
  class Field extends Backbone.Model

    # Local cache for models.
    @collection: new _Fields @

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: '_id'

    # Initialization logic: declare dynamic properties for each of model's attributes
    initialize: =>
      names = _.keys @attributes
      for name in names
        ((name) =>
          unless Object.getOwnPropertyDescriptor(@, name)?
            Object.defineProperty @, name,
              enumerable: true
              configurable: true
              get: -> @get name
              set: (v) -> @set name, v
        )(name)

    # Provide a custom sync method to wire Types to the server.
    # Only create and delete operations are supported.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      switch method 
        when 'create' then Field.collection.save [@]
        when 'delete' then Field.collection.destroy [@]
        else throw new Error "Unsupported #{method} operation on #{@_className}"

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current item is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @id is other?.id
