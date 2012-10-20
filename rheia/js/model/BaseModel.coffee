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
  'underscore'
  'utils/utilities'
], (Backbone, _, utils) ->

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

    # **private**
    # List of attributes that must not be updated
    _notUpdated: ['_id']

    # Collection constructor, that wired on events.
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (@model, @options) ->
      super options

      utils.onRouterReady =>
        # bind _onGetList response
        rheia.sockets.admin.on 'list-resp', @_onGetList

        # bind updates
        rheia.sockets.updates.on 'creation', @_onAdd
        rheia.sockets.updates.on 'update', @_onUpdate
        rheia.sockets.updates.on 'deletion', @_onRemove

    # Provide a custom sync method to wire model to the server.
    # Only read operation is supported.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      throw new Error "Unsupported #{method} operation on #{@_className}" unless method is 'read'
      rheia.sockets.admin.emit 'list', @_className

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
      model = @get changes[@model.prototype.idAttribute]
      return unless model?
      # then, update the local cache.
      model.set key, value for key, value of changes unless key in @_notUpdated

      # emit a change.
      @trigger 'update', model, @, changes
      model.trigger 'update', model, changes
      # propagates changes on collection to global change event
      rheia.router.trigger 'modelChanged'

    # **private**
    # Callback invoked when a database deletion is received.
    # Removes the model from the current collection if needed, and fire event 'remove'.
    #
    # @param className [String] the deleted object className
    # @param model [Object] deleted model.
    # @param options [Object] remove event options
    _onRemove: (className, model, options = {}) =>
      return unless className is @_className
      # removes the deleted item after enrich it to allow recognition. An event will be triggered
      @remove new @model(model), options
      # propagates changes on collection to global change event
      rheia.router.trigger 'modelChanged'

  # BaseLinkedCollection provides common behaviour for model wih linked objects collections.
  #
  # Reconstruct the type when updates found
  class BaseLinkedCollection extends BaseCollection

    # Class of the type of this model.
    # **Must be defined by subclasses**
    @typeClass: null

    # Constructor.
    # Requires at least candidate classes
    constructor: (@model, @options) ->
      super @model, options
      # require linked cnadidate if needed
      require @model.linkedCandidateClassesScript

    # **private**
    # Callback invoked when a database update is received.
    # Update the model from the current collection if needed, and fire event 'update'.
    # Extension to resolve type when needed
    #
    # @param className [String] the modified object className
    # @param changes [Object] new changes for a given model.
    _onUpdate: (className, changes) =>
      return unless className is @_className
      # always keep an up-to-date type
      model = @get changes[@model.prototype.idAttribute]
      model?.set 'type', @constructor.typeClass.collection.get model.get('type')?.id

      # Call inherited merhod
      super className, changes

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
          rheia.sockets.admin.once 'save-resp', (err) =>
            rheia.router.trigger 'serverError', err, method:"#{@_className}.sync", details:method, id:@id if err?
          rheia.sockets.admin.emit 'save', @_className, @_serialize()
        when 'delete' 
          rheia.sockets.admin.once 'remove-resp', (err) =>
            rheia.router.trigger 'serverError', err, method:"#{@_className}.sync", details:method, id:@id if err?
          rheia.sockets.admin.emit 'remove', @_className, @_serialize()
        else throw new Error "Unsupported #{method} operation on #{@_className}"

    # Enhance destroy method to force server response before triggering `destroy` event
    destroy: (options) =>
      options = options or {}
      options.wait = true
      super options

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Uses the Backbone @toJSON() existing method
    #
    # @return a serialized version of this model
    _serialize: => @toJSON()

    # An equality method that tests ids.
    #
    # @param other [Object] the object against which the current item is tested
    # @return true if both object have the samge ids, and false otherwise.
    equals: (other) =>
      @.id is other?.id

  # BaseLinkedModel provides common behaviour for model with linked properties.
  # 
  # It resolve type during construction (and trigger `typeFetched` when finished if type was not available).
  # It adds a `getLinked` instance method to resolve linked properties
  class BaseLinkedModel extends BaseModel

    # Class of the type of this model.
    # **Must be defined by subclasses**
    @typeClass: null

    # Array of path of classes in which linked objects are searched.
    # **Must be defined by subclasses**
    @linkedCandidateClasses: []

    # LinkedModel constructor.
    # Will fetch type from server if necessary, and trigger the `typeFetched` when finished.
    #
    # @param attributes [Object] raw attributes of the created instance.
    constructor: (attributes) ->
      delete attributes.className
      super attributes

      # Construct an type around the raw type.
      if attributes?.type?
        typeId = attributes.type
        if typeof attributes.type is 'object'
          typeId = attributes.type[@idAttribute]

        # resolve by id
        type = @constructor.typeClass.collection.get typeId
        # not found on client
        unless type?
          if typeof attributes.type is 'object'
            # we have all informations: just adds it to collection
            type = new @constructor.typeClass attributes.type
            @constructor.typeClass.collection.add type
            @set 'type', type
            @trigger 'typFetched', @
          else
            # get it from server
            @constructor.typeClass.collection.on 'add', @_onTypeFetched
            @constructor.typeClass.collection.fetch attributes.type
        else 
          @set 'type', type
          @trigger 'typFetched', @

    # Handler of type retrieval. Updates the current type with last values
    #
    # @param type [Type] an added type.      
    _onTypeFetched: (type) =>
      if type.id is @get 'type'
        console.log "type #{type.id} successfully fetched from server for #{@_className.toLowerCase()} #{@id}"
        # remove handler
        @constructor.typeClass.collection.off 'add', @_onTypeFetched
        # update the type object
        @set 'type', type
        @trigger 'typFetched', @

    # This method retrieves linked Event in properties.
    # All `object` and `array` properties are resolved. 
    # Properties that aims at unexisting linked are reset to null.
    #
    # @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
    # @option callback err [String] an error message if an error occured.
    # @option callback instance [BaseLinkedModel] the root instance on which linked were resolved.
    getLinked: (callback) =>
      needResolution = false
      # identify each linked properties 
      console.log "search linked ids in #{@_className.toLowerCase()} #{@id}"
      # gets the corresponding properties definitions
      properties = @get('type').get 'properties'
      for prop, def of properties
        value = @get prop
        if def.type is 'object' and typeof value is 'string'
          # try to get it locally first in same class and in other candidate classes
          objValue = @constructor.collection.get value
          unless objValue?
            for candidateScript in @constructor.linkedCandidateClasses
              objValue = require(candidateScript).collection.get value
              break if objValue?
          if objValue?
            @set prop, objValue
          else
            # linked not found: ask to server
            needResolution = true
            break
        else if def.type is 'array' 
          value = [] unless value?
          for linked, i in value when typeof linked is 'string'
            # try to get it locally first in same class and in other candidate classes
            objLinked = @constructor.collection.get linked
            unless objLinked?
              for candidateScript in @constructor.linkedCandidateClasses
                objLinked = require(candidateScript).collection.get linked
                break if objLinked?
            if objLinked?
              value[i] = objLinked
            else
              # linked not found: ask to server
              needResolution = true
              break
          break if needResolution
      
      # exit immediately if no resolution needed  
      unless needResolution
        return _.defer => 
          console.log "linked ids for #{@_className.toLowerCase()} #{@id} resolved from cache"
          callback null, @ 

      # now that we have the linked ids, get the corresponding instances.
      rheia.sockets.game.once "get#{@_className}s-resp", (err, instances) =>
        return callback "Unable to resolve linked on #{@id}. Error while retrieving linked: #{err}" if err?
        instance = instances[0]

        # update each properties
        properties = @get('type').get 'properties'
        for prop, def of properties
          value = instance[prop]
          if def.type is 'object'
            if value isnt null
              # construct a backbone model around linked object
              clazz = @constructor
              for candidateScript in @constructor.linkedCandidateClasses when candidateScript is "model/#{value.className}"
                clazz = require(candidateScript)
              obj = new clazz value
              clazz.collection.add obj
            else
              obj = null
            # update current object
            @set prop, obj
          else if def.type is 'array' 
            value = [] unless value?
            for val, i in value
              # construct a backbone model around linked object
              clazz = @constructor
              for candidateScript in @constructor.linkedCandidateClasses when candidateScript is "model/#{val.className}"
                clazz = require(candidateScript)
              obj = new clazz val
              clazz.collection.add obj
              # update current object
              @get(prop)[i] = obj

        # end of resolution.
        console.log "linked ids for #{@_className.toLowerCase()} #{@id} resolved"
        callback null, @

      rheia.sockets.game.emit "get#{@_className}s", [@id]

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Only keeps ids in linked properties to avoid recursion, before returning JSON representation 
    #
    # @return a serialized version of this model
    _serialize: => 
      properties = @get('type').get 'properties'
      attrs = {}
      for name, value of @attributes
        if properties[name]?.type is 'object'
          attrs[name] = if 'object' is utils.type value then value?.id else value
        else if properties[name]?.type is 'array'
          linked = []
          attrs[name] = ((if 'object' is utils.type obj then obj?.id else obj) for obj in value)
        else
          attrs[name] = value
      # returns the json attributes
      attrs

  {
    Collection: BaseCollection
    Model: BaseModel
    LinkedCollection: BaseLinkedCollection
    LinkedModel: BaseLinkedModel
  }