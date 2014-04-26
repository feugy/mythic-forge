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

mongoose = require 'mongoose'
_ = require 'underscore'
fs = require 'fs'
path = require 'path'
async = require 'async'
conn = require './connection'
Executable = require '../model/Executable'
modelWatcher = require('./ModelWatcher').get()
logger = require('../util/logger').getLogger 'model'
utils = require '../util/common'
modelUtils = require '../util/model'

imageStore = utils.confKey 'game.image'

# cache of used ids for all managed type cache, populated at startup
idCache = {}
conn.loadIdCache idCache

# Bunch of inmemory caches.
# contain for each managed class (name as string) an associative array in which:
# - key is model ids
# - value is an object with "model" property (the model itself) "since" property (timestamp of last save)
caches = {}
modelUtils.evictModelCache caches, utils.confKey('cache.frequency'), utils.confKey 'cache.maxAge'

# update local cache when removing an instance or creating one
modelWatcher.on 'change', (operation, className, changes) ->
  if operation is 'creation'
    idCache[changes.id] = 1
  else if operation is 'deletion' and changes.id of idCache
    delete idCache[changes.id]
modelWatcher.on 'executableReset', (removed) ->
  delete idCache[id] for id in removed when id of idCache

# Extends _registerHook to construct dynamic properties in Document constructor
original_registerHooks = mongoose.Document::$__registerHooks
mongoose.Document::$__registerHooks = ->
  ret = original_registerHooks.apply @, arguments
  @_defineProperties()
  ret

# Compares an array property to its original value.
# The original value is searched inside the __origXXX attribute when XXX is the property name
# Only ids (String version) are compared
#
# @param instance [Object] Mongoose instance which is analyzed and may be marked as modified
# @param prop [String] name of the compared properties
compareArrayProperty = (instance, prop) ->
  original = instance["__orig#{prop}"] or []
  # original contains, ids, current may also contain Mongoose objects
  current = _.map instance[prop] or [], (linked) -> if 'object' is utils.type(linked) and linked?.id? then linked.id else linked
  # compare original value and current dynamic value and mark modified if necessary
  instance.markModified prop unless _.isEqual original, current

# Compares an object property with arbitrary content to its original value.
# The original value is searched inside the __origXXX attribute when XXX is the property name
# The original value is intended to store a string representation of a value.
#
# @param instance [Object] Mongoose instance which is analyzed and may be marked as modified
# @param prop [String] name of the compared properties
compareObjProperty = (instance, prop) ->
  original = instance["__orig#{prop}"] or "{}"
  current = JSON.stringify instance[prop] or {}
  instance.markModified prop unless original is current
    
originalIsModified = mongoose.Document::isModified
mongoose.Document::isModified = (path) ->
  # detect modification on dynamic arrays
  if @type?.properties?
    for prop, value of @type.properties 
      switch value.type 
        when 'array' then compareArrayProperty @, prop 
        when 'json' then compareObjProperty @, prop 

  # detect modification on characters array
  if @_className is 'Player' 
    compareArrayProperty @, 'characters'
    compareObjProperty @, 'prefs'

  originalIsModified.apply @, arguments

# Initialize dynamic properties from type when needed
mongoose.Document::_defineProperties = ->
  if @type?.properties?
    # define setters and getters for properties once the instance have been initialized
    for name, prop of @type.properties
      ((name) =>
        unless Object.getOwnPropertyDescriptor(@, name)?
          Object.defineProperty @, name,
            enumerable: true
            configurable: true
            get: -> @get name
            set: (v) -> @set name, v
      )(name)

# Factory that creates an abstract type.
# Provides:
# - id primary key
# - id-based `equals` method
# - modelWatcher usage
# - cache functionnalities and `findCached` static method
# - image storage with `saveImage`and `removeImage`
# - properties management, for type or instances
#
# @param typeName [String] name of the build type, used for changes propagations
# @param spec [Object] attributes of the created type.
# @param options [Object] Mongoose schema options, and factory custom options:
# @option options typeProperties [Boolean] whether this type will defined properties for its instances
# @option options instanceClass [String] if this type has type-properties, the instance class name
# @option options instanceProperties [Boolean] wether this type will embed properties
# @option options typeClass [Object] if this type has instance-properties, the type class name
# @option options hasImages [Boolean] if this type has images to be removed when type is removed
# @option options middlewares [Object] type middleware, added before other middlewares
# @return the created type
module.exports = (typeName, spec, options = {}) ->

  caches[typeName] = {}

  # when receiving a change from another worker, update the instance cache
  modelWatcher.on 'change', (operation, className, changes, wId) ->
    wId = wId or process.pid
    return unless className is typeName and caches[typeName][changes?.id]?
    # update the cache
    switch operation
      when 'update'
        # if comming from your process, no need to updated
        unless wId is process.pid
          caches[typeName][changes.id].since = new Date().getTime()
          instance = caches[typeName][changes.id].model
          # partial update
          # do not use setter to avoid marking the instance as modified.
          for attr, value of changes when !(attr in ['id', '__v'])
            instance._doc[attr] = value  
            if "__orig#{attr}" of instance
              if _.isArray instance["__orig#{attr}"]
                # object array
                instance["__orig#{attr}"] = _.map value or [], (o) -> if 'object' is utils.type(o) and o?.id? then o.id else o
              else
                # arbitrary JSON
                instance["__orig#{attr}"] = JSON.stringify value or {}
      when 'deletion' 
        delete caches[typeName][changes.id]

  spec.versionKey = false
  
  if options.typeProperties
    # event properties definition, stored by names
    # @example property definition include
    #   property: {
    #     # property type, within: string, text, boolean, integer, float, date, array or object
    #     type: {type: String, required: true}
    #     # default value applied
    #     def: {type: {}, required: true}
    spec.properties =
      type: {}
      default: -> {} # use a function to force instance variable

  if options.instanceProperties
    # link to type, mandatory to retrieve properties definitions
    spec.type = 
      type: {}
      required: true


  # Extends original Mongoose toObject method to add className when requireing json.
  options.toObject = 
    transform: (doc, ret, options) ->
      if options?.json
        ret._className = doc._className
        # special case of plain json property that is ignored by mongoose.utils.clone()
        if doc._className is 'Player'
          ret.prefs = doc.prefs
      ret

  # Extends original Mongoose toJSON method to add className and changing _id to id.
  options.toJSON = 
    transform: (doc, ret, opts) ->
      if options.typeProperties
        # avoid pruning empty json objects (can be default values of properties)
        ret.properties = _.extend {}, doc.properties
      ret._className = doc._className
      # special case of plain json property that is ignored by mongoose.utils.clone()
      if doc._className is 'Player'
        ret.prefs = doc.prefs
      ret.id = ret._id
      delete ret._id
      delete ret.__v
      ret

  options._id = false
  spec._id = String

  # Abstract schema, that can contains i18n attributes
  AbstractType = new mongoose.Schema spec, options

  # Define a virtual getter on model's class name.
  # Handy when models have been serialized to distinguish them
  AbstractType.virtual('_className').get -> typeName

  # manually manage ids within the 'id' attribute, and store them into the '_id' attribute.
  # Define a virtual getter on model's class name.
  # Handy when models have been serialized to distinguish them
  AbstractType.virtual('id').set (value) -> @_id = value

  # Override the equals() method defined in Document, to check correctly the equality between ids, 
  # with their `equals()` method and not with the strict equality operator.
  #
  # @param other [Object] other object against which the current object is compared
  # @return true if both objects have the same id, false otherwise
  AbstractType.methods.equals = (object) ->
    return false unless 'string' is utils.type object?.id
    @id is object.id

  # Adds custom middleware first
  if 'object' is utils.type options.middlewares
    AbstractType.pre name, middleware for name, middleware of options.middlewares

  # This special finder maintains an in-memory cache of objects, to faster type retrieval by ids.
  # If ids aren't found in cache, search in database.
  #
  # @param ids [Array] the searched ids.
  # @param callback [Function] the callback function, that takes two parameters
  # @option callback err [String] an error string, or null if no error occured
  # @option callback obj [Array] the found types. May be empty.
  AbstractType.statics.findCached = (ids, callback) ->
    ids = _.uniq(ids) or [];
    notCached = []
    cached = []
    # first look into the cache (order is preserved)
    for id in ids 
      if id of caches[typeName]
        cached.push caches[typeName][id].model
      else
        notCached.push id
    return _.defer(-> callback null, cached) if notCached.length is 0
    # then into the database
    @find {_id: $in: notCached}, (err, results) =>
      return callback err if err?
      # keep the original order
      callback null, (caches[typeName][id].model for id in ids when caches[typeName][id]?)

  # Load the different ids from MongoDB.
  # **Warning:** this method uses it's own dedicated MongoDB connection. 
  # Intended to tests: do not use in production
  #
  # @param callback [Function] loading end callback.
  AbstractType.statics.loadIdCache = (callback) ->
    throw new Error 'Never use it in production!' if process.env.NODE_ENV isnt 'test'
    idCache = {}
    conn.loadIdCache idCache, callback

  # Check if a model is cached, and since when
  #
  # @returns the timestamp since when a model is cached.
  AbstractType.statics.cachedSince = (id) ->
    if id of caches[typeName] then caches[typeName][id].since else 0

  # Clean model cache for this model class or all cached models
  #
  # @param all [Boolean] true (default) to clean all models, false to clean models of this class
  AbstractType.statics.cleanModelCache = (all = true) ->
    for className of caches
      caches[className] = {} if className is typeName or all

  # Indicates whether or not an id is used
  #
  # @param id [String] tested id
  # @return true if id is used
  AbstractType.statics.isUsed = (id) -> 
    id of idCache or Executable.findCached([id]).length isnt 0

  # post-init middleware: populate the cache
  AbstractType.post 'init', ->
    # store in cache
    caches[typeName][@id] = model:@, since: new Date().getTime()
  
  # post-save middleware: update cache
  AbstractType.post 'save',  ->
    # now that the instance was properly saved, update the cache.
    caches[typeName][@id] = model:@, since: new Date().getTime()
    
  # post-remove middleware: now that the type was properly removed, update the cache.
  AbstractType.post 'remove', ->
    # updates the cache
    delete caches[typeName][@id]

    # to avoid circular dependencies, replace links by their ids in properties
    modelUtils.processLinks @, @type.properties if options.instanceProperties
        
    # broadcast deletion
    modelWatcher.change 'deletion', typeName, @
    if options.hasImages
      # removes all images that starts with the id from the image store.
      id = @id
      fs.readdir imageStore, (err, files) ->
        # during test, image folder may have been deleted
        return if err?.code is 'ENOENT'
        for file in files when file.indexOf("#{id}-") is 0
          fs.unlink path.join imageStore, file

  if options.typeProperties

    # setProperty() adds or updates a property.
    #
    # @param name [String] the unic name of the property.
    # @param type [String] primitive type of the property's values. Could be: string, text, boolean, integer, float, date, array or object
    # @param def [Object] default value affected to the type instances.
    AbstractType.methods.setProperty = (name, type, def) ->
      # Do not store strings, store dates instead
      def = new Date def if type is 'date' and 'string' is utils.type def
      @properties[name] = {type: type, def: def}
      @markModified 'properties'
      @_updatedProps = [] unless @_updatedProps?
      @_updatedProps.push name

    # unsetProperty() removes a property. All existing instances loose their own property value.
    # Will throw an error if the property does not exists.
    #
    # @param name [String] the unic name of the property.
    AbstractType.methods.unsetProperty = (name) ->
      throw new Error "Unknown property #{name} for type #{@id}" unless @properties[name]?
      delete @properties[name]
      @markModified 'properties'
      @_deletedProps = [] unless @_deletedProps?
      @_deletedProps.push name

    # pre-save middleware: update type instances' properties if needed.
    AbstractType.pre 'save', (next) ->
      return next() unless @_updatedProps? or @_deletedProps?        

      # get type instances
      require("./#{options.instanceClass}").find {type: @id}, (err, instances) =>
        return next new Error "Failed to update type instances: #{err}" if err?
        saved = []
        for instance in instances
          # add default value in instances that do not have the added properties yet.
          if @_updatedProps?
            for name in @_updatedProps
              prop = @properties[name]
              def = prop.def
              switch prop.type
                when 'array' then def = []
                when 'object' then def = null

              # check default values              
              err = modelUtils.checkPropertyType def, prop
              return next new Error err if err?

              # if property isn't defined: set default
              if undefined is instance.get name
                # use getter here because property was not defined yet
                instance.set name, def
                saved.push instance unless saved in instance

          # removes deleted properties from instances.
          if @_deletedProps?
            for name in @_deletedProps

              instance.set name, undefined
              delete instance._doc[name]
              saved.push instance unless saved in instance

        delete @_deletedProps
        delete @_updatedProps
        # save all the modified instances
        async.forEach saved, (instance, done) -> 
          instance.save done
        , next

  if options.instanceProperties

    # pre-init middleware: retrieve the type corresponding to the stored id.
    #
    # @param instance [Object] the initialized instance.
    # @param next [Function] function that must be called to proceed with other middleware.
    # Calling it with an argument indicates the the validation failed and cancel the instance save.
    AbstractType.pre 'init', (next, instance) ->
      # loads the type from local cache
      require("./#{options.typeClass}").findCached [instance.type], (err, types) ->
        return next(new Error "Unable to init instance #{instance.id}. Error while resolving its type: #{err}") if err?
        return next(new Error "Unable to init instance #{instance.id} because there is no type with id #{instance.type}") unless types.length is 1    
        # do the replacement
        instance.type = types[0]
        next()

    # post-init middleware: define dynamic properties
    AbstractType.post 'init', ->
      @_defineProperties()
      # for each array property, add a save with linked ids to allow further comparisons
      for name, spec of @type.properties 
        if spec.type is 'array'
          @["__orig#{name}"] = @[name]?.concat() or [] 
        else if spec.type is 'json'
          @["__orig#{name}"] = JSON.stringify @[name] or {}

    # This method retrieves linked objects in properties.
    # All `object` and `array` properties are resolved. 
    # Properties that aims at unexisting objects are reset to null.
    # Works in two modes: 
    # - read only from DB (breakCycles = true): it ensure not returning cyclic model trees, but same entity may be presented by two different models
    # - read both in DB and cache (breakCycles = false): ensure entity uniquness, but may return cyclic model trees
    #
    # @param breakCycles [Boolean] true to break entities cycle, default to false
    # @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
    # @option callback err [String] an error message if an error occured.
    # @option callback instance [Object] the root instance on which linked objects were resolved.
    AbstractType.methods.fetch = (breakCycles, callback) ->
      if _.isFunction breakCycles
        [callback, breakCycles] = [breakCycles, true]
      AbstractType.statics.fetch [this], breakCycles, (err, instances) =>
        callback err, instances?[0] or null

    # This static version of `fetch` performs multiple linked objects resolution in one operation.
    # See `fetch()` for more information.
    #
    # @param instances [Array<Object>] an array that contains instances which are resoluved.
    # @param breakCycles [Boolean] true to break entities cycle, default to false
    # @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
    # @option callback err [String] an error message if an error occured.
    # @option callback instances [Array<Object>] the instances on which linked objects were resolved.
    AbstractType.statics.fetch = (instances, breakCycles, callback) ->
      if _.isFunction breakCycles
        [callback, breakCycles] = [breakCycles, true]
      ids = []
      # identify each linked properties 
      for instance in instances
        logger.debug "search linked ids in #{instance.id}"
        # gets the corresponding properties definitions
        properties = instance.type.properties
        for prop, def of properties
          value = instance[prop]
          if def.type is 'object'
            unless breakCycles
              # if cache is used, always fetch value
              if value?.id? or 'string' is utils.type value
                logger.debug "found #{value.id or value} in property #{prop}"
                ids.push value.id or value
            else if 'string' is utils.type value
              # otherwise, only kept unresolved values
              logger.debug "found #{value} in property #{prop}"
              ids.push value
          else if def.type is 'array' and value?.length > 0
            for val in value
              unless breakCycles
                # if cache is used, always fetch value
                if val?.id? or 'string' is utils.type val
                  logger.debug "found #{val.id or val} in property #{prop}"
                  ids.push val.id or val
              else if 'string' is utils.type val
                # otherwise, only kept unresolved values
                logger.debug "found #{val} in property #{prop}"
                ids.push val
      
      # now that we have the linked ids, get the corresponding instances.
      return callback(null, instances) unless ids.length > 0
      
      # resolve in both items and events
      linked = []
      async.forEach [{name: 'Item', clazz:require('./Item')}, {name: 'Event', clazz:require('./Event')}], (spec, end) ->
        # two modes: 
        # - read only from DB (breakCycles = true): it ensure not returning cyclic model trees, but same entity may be presented by two different models
        # - read both in DB and cache (breakCycles = false): ensure entity uniquness, but may return cyclic model trees
        cachedIds = if breakCycles then [] else _.intersection ids, _.keys caches[spec.name]
        if cachedIds.length > 0
          # immediately add cached entities
          linked = linked.concat (caches[spec.name][id].model for id in cachedIds)
        # quit if no more ids to read
        return end() if cachedIds.length is ids.length
        # read remaining ids from DB
        spec.clazz.find _id: $in: _.difference(ids, cachedIds), (err, results) ->
          return callback("Unable to resolve linked on #{instances}. Error while retrieving linked: #{err}") if err?
          linked = linked.concat results
          end()
      , ->
        # process again each properties to replace ids with real objects, and remove unknown ids
        for instance in instances
          properties = instance.type.properties
          logger.debug "replace linked ids in #{instance.id}"
          for prop, def of properties
            value = instance._doc[prop]
            if def.type is 'object'
              link = null
              for l in linked
                if l.id is (value?.id or value)
                  link = l
                  break
              logger.debug "replace with object #{link?.id} in property #{prop}"
              # do not use setter to avoid marking the instance as modified.
              instance._doc[prop] = link
            else if def.type is 'array' and value?.length > 0
              result = []
              for val, i in value
                result[i] = _.find linked, (link) -> link.id is (val?.id or val)
                logger.debug "replace with object #{result[i]?.id} position #{i} in property #{prop}"
              # filter null values
              # do not use setter to avoid marking the instance as modified.
              instance._doc[prop] = _.filter result, (obj) -> obj?
              # add a save with linked ids to allow further comparisons
              instance["__orig#{prop}"] = _.map instance._doc[prop], (obj) -> obj.id

        # done !
        callback null, instances
          
    # pre-save middleware: enforce the existence of each property. 
    # Could be declared in the schema, or in the type's properties
    # Inside the middleware, `this` aims at the saved instance.
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    # Calling it with an argument indicates the the validation failed and cancel the instante save.
    AbstractType.pre 'save', (next) ->
      return next new Error "Cannot save instance #{@_className} (#{@id}) without type" unless @type?

      properties = @type.properties
      # get through all existing attributes
      attrs = Object.keys @_doc;
      for attr in attrs when attr isnt '__v' # ignore versionning attribute
        # not in schema, nor in type
        if attr of properties
          # use not property cause it's not always defined at this moment
          err = modelUtils.checkPropertyType @_doc[attr], properties[attr] 
          next(new Error "Unable to save instance #{@id}. Property #{attr}: #{err}") if err?
        else unless attr of AbstractType.paths
          next new Error "Unable to save instance #{@id}: unknown property #{attr}"

      # set the default values
      for prop, value of properties
      
        if undefined is @_doc[prop]
          @_doc[prop] = if value.type is 'array' then [] else if value.type is 'object' then null else value.def

        # Do not store strings, store dates instead
        if value.type is 'date' and 'string' is utils.type @_doc[prop]
          @_doc[prop] = new Date @_doc[prop]
          
      wasNew = @isNew
      # generate id if necessary
      @id = modelUtils.generateId() unless @id? or !wasNew
      if wasNew
        # validates id 
        return next new Error "id #{@id} for model #{typeName} is invalid" unless modelUtils.isValidId @id
        return next new Error "id #{@id} for model #{typeName} is already used" if @id of idCache
      else
        # do not change the id once created
        return next new Error "id cannot be changed on a #{typeName}" if @isModified '_id' 

      # stores the isNew status and modified paths now, to avoid registering modification on wrong attributes.
      modifiedPaths = @modifiedPaths().concat()
      # replace links by them ids
      modelUtils.processLinks @, properties
      # replace type with its id, for storing in Mongo, without using setters.
      saveType = @type
      @_doc.type = saveType?.id
      next()
      # for each array property, add a save with linked ids to allow further comparisons
      for name, spec of saveType.properties 
        if spec.type is 'array'
          @["__orig#{name}"] = @_doc[name]?.concat() or []
        else if spec.type is 'json'
          @["__orig#{name}"] = JSON.stringify @_doc[name] or {}
      # restore save to allow reference reuse.
      @_doc.type = saveType
      # propagate modifications
      modelWatcher.change (if wasNew then 'creation' else 'update'), typeName, @, modifiedPaths

  else

    # pre-save middleware: trigger model watcher.
    # Not used for schemas with instanceProperties, because they handled themselves their modifications
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    # Calling it with an argument indicates the the validation failed and cancel the instante save.
    AbstractType.pre 'save', (next) ->
      wasNew = @isNew
      # generate id if necessary
      @id = modelUtils.generateId() unless @id? or !wasNew
      if wasNew
        # validates id 
        return next new Error "id #{@id} for model #{typeName} is invalid" unless modelUtils.isValidId @id
        return next new Error "id #{@id} for model #{typeName} is already used" if @id of idCache
      else
        # do not change the id once created
        return next new Error "id cannot be changed on a #{typeName}" if @isModified '_id' 
        
      # stores the isNew status and modified paths.
      modifiedPaths = @modifiedPaths().concat()
      next()
      # propagate modifications
      modelWatcher.change (if wasNew then 'creation' else 'update'), typeName, @, modifiedPaths
    
  return AbstractType