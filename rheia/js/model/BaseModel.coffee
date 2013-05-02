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
    _notUpdated: ['id']

    # Collection constructor, that wired on events.
    #
    # @param model [Object] the managed model
    # @param options [Object] unused
    constructor: (@model, @options) ->
      super options

      utils.onRouterReady =>
        # bind _onGetList response
        app.sockets.admin.on 'list-resp', @_onGetList
        app.sockets.game.on 'getTypes-resp', (reqId, err, types) =>
          # ignore errors
          unless err?
            # add returned models of the current class
            @_onAdd type._className, type for type in types 

        # bind updates
        app.sockets.updates.on 'creation', @_onAdd
        app.sockets.updates.on 'update', @_onUpdate
        app.sockets.updates.on 'deletion', @_onRemove

    # Provide a custom sync method to wire model to the server.
    # Only read operation is supported.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      throw new Error "Unsupported #{method} operation on #{@_className}" unless method is 'read'
      app.sockets.admin.emit 'list', utils.rid(), @_className

    # **private**
    # Return handler of `list` server method.
    #
    # @param reqId [String] client request id
    # @param err [String] error message. Null if no error occured
    # @param modelName [String] reminds the listed class name.
    # @param models [Array<Object>] raw models.
    _onGetList: (reqId, err, modelName, models) =>
      return unless modelName is @_className
      return app.router.trigger 'serverError', err, method:"#{@_className}.collection.sync", details:'read' if err?
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
      app.router.trigger 'modelChanged', 'add',  @get model[@model.prototype.idAttribute]

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
      # console.log "process update for model #{model.id} (#{model._className})", changes
      # then, update the local cache, using setter do defines dynamic properties if needed
      modified = false
      for key, value of changes
        unless key in @_notUpdated
          modified = true
          model.set key, value 
          # console.log "update property #{key}"

      # emit a change.
      @trigger 'update', model, @, changes
      model.trigger 'update', model, changes
      # propagates changes on collection to global change event
      app.router.trigger 'modelChanged', 'update', model

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
      removed = @get model[@model.prototype.idAttribute]
      # removes the deleted item
      if removed
        @remove removed 
        removed.trigger 'destroy', removed, @, options
        # propagates changes on collection to global change event
        app.router.trigger 'modelChanged', 'remove', removed

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
    # Callback invoked when a database creation is received.
    # Adds the model to the current collection if needed, and fire event 'add'.
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onAdd: (className, model) =>
      return unless className is @_className
      # before adding the model, wait for its type to be fetched
      model = @_prepareModel model
      model.on 'typeFetched', =>
        # add the created raw model. An event will be triggered
        @add model
        # propagates changes on collection to global change event
        app.router.trigger 'modelChanged', 'add', model

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
      model?.type = @constructor.typeClass.collection.get model.type?.id

      # Call inherited merhod
      super className, changes

  # BaseModel provides common behaviour for model.
  #
  # The `sync` method is wired to server Api `save` and  `remove` when creating, updating and destroying models.
  # `equals` method is provided
  class BaseModel extends Backbone.Model

    # Local cache for models.
    # **Must be defined by subclasses**
    @collection = null

    # bind the Backbone attribute and the MongoDB attribute
    idAttribute: 'id'

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    # **Must be defined by subclasses**
    _className: null

    # **private**
    # List of properties that must be defined in this instance.
    # **May be defined by subclasses**
    _fixedAttributes: []

    # Initialization logic: declare dynamic properties for each of model's attributes
    initialize: =>    
      names = _.keys @attributes
      # define property on attributes that must be present
      names = _.uniq names.concat @_fixedAttributes
      for name in names
        unless name is 'id' or Object.getOwnPropertyDescriptor(@, name)?
          ((name) =>
          
            Object.defineProperty @, name,
              enumerable: true
              configurable: true
              get: -> @get name
              set: (v) -> @set name, v
          )(name)

    # Overrides inherited setter to declare dynamic property
    #
    # @param attr [String] the modified attribute
    # @param value [Object] the new attribute value
    # @param options [Object] optionnal set options
    set: (attr, value, options) =>
      # treat single attribute
      single = (name) =>
        # define property if needed
        unless name is 'id' or Object.getOwnPropertyDescriptor(@, name)?
          Object.defineProperty @, name,
            enumerable: true
            configurable: true
            get: -> @get name
            set: (v) -> @set name, v

      # Always works in 'object mode'
      unless 'object' is utils.type attr
        obj = {}
        obj[attr] = value
        attr = obj
      else
        options = value
    
      single attrName for attrName of attr

      # supperclass processing
      super attr, options

    # Provide a custom sync method to wire Types to the server.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments
    sync: (method, collection, args) =>
      rid = utils.rid();
      switch method 
        when 'create', 'update' 
          # add object if creation
          @constructor.collection.add @ if 'create'
          app.sockets.admin.on 'save-resp', listener = (reqId, err) =>
            return unless rid is reqId
            app.sockets.admin.removeListener 'save-resp', listener
            app.router.trigger 'serverError', err, method:"#{@_className}.sync", details:method, id:@id if err?
          app.sockets.admin.emit 'save', rid, @_className, @_serialize()
        when 'delete' 
          app.sockets.admin.on 'remove-resp', listener = (reqId, err) =>
            return unless rid is reqId
            app.sockets.admin.removeListener 'remove-resp', listener
            app.router.trigger 'serverError', err, method:"#{@_className}.sync", details:method, id:@id if err?
          app.sockets.admin.emit 'remove', rid, @_className, @_serialize()
        when 'read'
          app.sockets.game.emit 'getTypes', rid, [@[@idAttribute]]

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
      @id is other?.id

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
        if 'object' is utils.type attributes.type
          typeId = attributes.type[@idAttribute]

        # resolve by id
        type = @constructor.typeClass.collection.get typeId
        # not found on client
        unless type?
          if 'object' is utils.type attributes.type
            # we have all informations: just adds it to collection
            type = new @constructor.typeClass attributes.type
            @constructor.typeClass.collection.add type
            @type = type
            _.defer => @trigger 'typeFetched', @
          else
            # get it from server
            @constructor.typeClass.collection.on 'add', @_onTypeFetched
            type = {}
            type[@idAttribute] = typeId
            new @constructor.typeClass(type).fetch()
        else 
          @type = type
          _.defer => @trigger 'typeFetched', @
      
      # update if one of linked model is removed
      app.router.on 'modelChanged', (kind, model) => 
        return unless kind is 'remove' and !@equals model

        properties = @type.properties
        return unless properties?
        changes = {}
        # process each properties
        for prop, def of properties
          value = @[prop]
          if def.type is 'object' and model.equals value
            @[prop] = null
            changes[prop] = null
          else if def.type is 'array' 
            value = [] unless value?
            modified = false
            value = _.filter value, (linked) -> 
              if model.equals linked
                modified = true
                false
              else
                true
            if modified
              @[prop] = value
              changes[prop] = value

        # indicate that model changed
        unless 0 is _.keys(changes).length
          console.log "update model #{@id} after removing a linked object #{model.id}"
          @trigger 'update', @, changes

    # Handler of type retrieval. Updates the current type with last values
    #
    # @param type [Type] an added type.      
    _onTypeFetched: (type) =>
      if type.id is @type
        console.log "type #{type.id} successfully fetched from server for #{@_className.toLowerCase()} #{@id}"
        # remove handler
        @constructor.typeClass.collection.off 'add', @_onTypeFetched
        # update the type object
        @type = type
        @trigger 'typeFetched', @

    # Overrides inherited setter to handle type field.
    #
    # @param attr [String] the modified attribute
    # @param value [Object] the new attribute value
    # @param options [Object] optionnal set options
    set: (attr, value, options) =>

      # treat single attribute
      declareProps = =>
        # define property if needed
        for name of @type.properties when name isnt 'id' and !(Object.getOwnPropertyDescriptor(@, name)?)
          ((name) => 
            Object.defineProperty @, name,
              enumerable: true
              configurable: true
              get: -> @get name
              set: (v) -> @set name, v
          )(name)

      # Always works in 'object mode'
      unless 'object' is utils.type attr
        obj = {}
        obj[attr] = value
        attr = obj
      else
        options = value

      # enhance raw linked objects with their backbone models
      for name, def of @type?.properties when def.type in ['object', 'array'] and attr[name]?
        processed = attr[name]
        processed = [attr[name]] if 'object' is def.type
        modified = false
        for val, i in processed when val?._className? and !(val?.attributes?)
          modified = true
          # construct a backbone model around linked object
          clazz = @constructor
          for candidateScript in @constructor.linkedCandidateClasses when candidateScript is "model/#{val._className}"
            clazz = require(candidateScript)
          obj = clazz.collection.get val?.id
          unless obj?
            obj = new clazz val
            clazz.collection.add obj
          processed[i] = obj
            
        attr[name] = processed[0] if modified and 'object' is def.type
      
      # supperclass processing
      super attr, options

      declareProps() if attr?.type?

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
      properties = @type.properties
      return callback null, @ unless properties?
      for prop, def of properties
        value = @[prop]
        if def.type is 'object' and 'string' is utils.type value
          # try to get it locally first in same class and in other candidate classes
          objValue = @constructor.collection.get value
          unless objValue?
            for candidateScript in @constructor.linkedCandidateClasses
              objValue = require(candidateScript).collection.get value
              break if objValue?
          if objValue?
            @[prop] = objValue
          else
            # linked not found: ask to server
            needResolution = true
            break
        else if def.type is 'array' 
          value = [] unless value?
          for linked, i in value when 'string' is utils.type linked
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

      # process response
      rid = utils.rid()
      process = (reqId, err, instances) =>
        return unless rid is reqId
        app.sockets.game.removeListener "get#{@_className}s-resp", process

        return callback "Unable to resolve linked on #{@id}. Error while retrieving linked: #{err}" if err?
        instance = instances[0]
        # update each properties
        properties = @type.properties
        for prop, def of properties
          value = instance[prop]
          if def.type is 'object'
            if value?
              # construct a backbone model around linked object
              clazz = @constructor
              for candidateScript in @constructor.linkedCandidateClasses when candidateScript is "model/#{value._className}"
                clazz = require(candidateScript)
              obj = new clazz value
              clazz.collection.add obj
            else
              obj = null
            # update current object
            @[prop] = obj
          else if def.type is 'array' 
            value = [] unless value?
            @[prop] = []
            for val in value when val?
              # construct a backbone model around linked object
              clazz = @constructor
              for candidateScript in @constructor.linkedCandidateClasses when candidateScript is "model/#{val._className}"
                clazz = require(candidateScript)
              obj = new clazz val
              clazz.collection.add obj
              # update current object
              @[prop].push obj

        # end of resolution.
        console.log "linked ids for #{@_className.toLowerCase()} #{@id} resolved"
        callback null, @

      # now that we have the linked ids, get the corresponding instances.
      app.sockets.game.on "get#{@_className}s-resp", process
      app.sockets.game.emit "get#{@_className}s", rid, [@id]

    # **private** 
    # Method used to serialize a model when saving and removing it
    # Only keeps ids in linked properties to avoid recursion, before returning JSON representation 
    #
    # @return a serialized version of this model
    _serialize: => 
      properties = @type.properties
      attrs = {}
      for name, value of @attributes
        if properties?[name]?.type is 'object'
          attrs[name] = if 'object' is utils.type value then value?.id else value
        else if properties?[name]?.type is 'array'
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