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
ObjectId = require('mongodb').BSONPure.ObjectID
MongoClient = require('mongodb').MongoClient
modelWatcher = require('./ModelWatcher').get()
logger = require('../util/logger').getLogger 'model'
utils = require '../util/common'
modelUtils = require '../util/model'

imageStore = utils.confKey 'images.store'

# cache of used ids for all managed type cache, populated at startup
idCache = {}

# load ids of all existing models from database
loadIdCache = (callback = null) ->
  host = utils.confKey 'mongo.host', 'localhost'
  port = utils.confKey 'mongo.port', 27017
  db = utils.confKey 'mongo.db'
  user = utils.confKey 'mongo.user', null
  pass = utils.confKey 'mongo.password', null

  MongoClient.connect "mongodb://#{if user? and pass? then "#{user}:#{pass}@" else ''}#{host}:#{port}/#{db}", (err, db) ->
    throw new Error "Failed to connect to mongo to get ids: #{err}" if err?
    idCache = {}
    # get ids in each collections
    async.forEach ['players', 'items', 'itemtypes', 'events', 'eventtypes', 'maps', 'fieldtypes', 'clientconfs'], (name, next) ->
      db.collection(name).find({},fields: _id:1).toArray (err, results) ->
        return next err if err?
        idCache[obj._id] = 1 for obj in results
        next()
    , (err) ->
      throw new Error "Failed to retrieve ids of collection #{name}: #{err}" if err?
      # end the connection
      db.close()
      callback() if callback?

# update local cache when removing an instance or creating one
modelWatcher.on 'change', (operation, className, changes) ->
  if operation is 'creation'
    idCache[changes.id] = 1
  else if operation is 'deletion' and changes.id of idCache
    delete idCache[changes.id]
modelWatcher.on 'executableReset', (removed) ->
  delete idCache[id] for id in removed when id of idCache

loadIdCache()

# Extends _registerHook to construct dynamic properties in Document constructor
original_registerHooks = mongoose.Document.prototype._registerHooks
mongoose.Document.prototype._registerHooks = ->
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
  original = instance["__orig#{prop}"]
  return if original is undefined
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
  original = instance["_orig#{prop}"]
  current = JSON.stringify instance[prop] or {}
  instance.markModified prop unless original is current
    
originalIsModified = mongoose.Document.prototype.isModified
mongoose.Document.prototype.isModified = (path) ->
  # detect modification on dynamic arrays
  if @type?.properties?
    compareArrayProperty @, prop for prop, value of @type.properties when value.type is 'array'

  # detect modification on characters array
  if @_className is 'Player' 
    compareArrayProperty @, 'characters' if Array.isArray @characters
    compareObjProperty @, 'prefs'

  # detect modifications on arbitrary objects (ClientConf and Players)
  compareObjProperty @, 'values' if @_className is 'ClientConf'

  originalIsModified.apply @, arguments

# Initialize dynamic properties from type when needed
mongoose.Document.prototype._defineProperties = ->
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

  # Local cache
  cache = {}

  # when receiving a change from another worker, update the instance cache
  modelWatcher.on 'change', (operation, className, changes, wId) ->
    wId = wId or process.id
    return if wId is process.id or className isnt typeName or !(cache[changes?.id]?)
    # update the cache
    switch operation
      when 'update'
        # partial update
        # do not use setter to avoid marking the instance as modified.
        cache[changes.id]._doc[attr] = value for attr, value of changes when !(attr in ['id'])
      when 'deletion' 
        delete cache[changes.id]

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
        # removes orignal saves for array properties
        delete ret[prop] for prop of ret when 0 is prop.indexOf '__orig'
      ret

  # Extends original Mongoose toJSON method to add className and changing _id to id.
  options.toJSON = 
    transform: (doc, ret, options) ->
      ret._className = doc._className
      # special case of plain json property that is ignored by mongoose.utils.clone()
      if doc._className is 'Player'
        ret.prefs = doc.prefs
      # removes orignal saves for array properties
      delete ret[prop] for prop of ret when 0 is prop.indexOf '__orig'
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
    ids = _.uniq ids;
    notCached = []
    cached = []
    # first look into the cache
    for id in ids 
      if id of cache
        cached.push cache[id]
      else
        notCached.push id
    return _.defer(-> callback null, cached) if notCached.length is 0
    # then into the database
    @find {_id: $in: notCached}, (err, results) =>
      return callback err if err?
      callback null, cached.concat results


  # Load the different ids from MongoDB.
  # **Warning:** this method uses it's own dedicated MongoDB connection. 
  # Intended to tests: do not use in production
  #
  # @param callback [Function] loading end callback.
  AbstractType.statics.loadIdCache = (callback) ->
    throw new Error 'Never use it in production!' if process.env.NODE_ENV isnt 'test'
    loadIdCache callback

  # Indicates whether or not an id is used
  #
  # @param id [String] tested id
  # @return true if id is used
  AbstractType.statics.isUsed = (id) -> id of idCache

  # post-init middleware: populate the cache
  AbstractType.post 'init', ->
    # store in cache
    cache[@id] = @
  
  # post-save middleware: update cache
  AbstractType.post 'save',  ->
    # now that the instance was properly saved, update the cache.
    cache[@id] = @
    
  # post-remove middleware: now that the type was properly removed, update the cache.
  AbstractType.pre 'remove', (next) ->
    # do removal
    next()
    # updates the cache
    delete cache[@id]
    # broadcast deletion
    modelWatcher.change 'deletion', typeName, @
    if options.hasImages
      # removes all images that starts with the id from the image store.
      id = @id
      fs.readdir imageStore, (err, files) ->
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

              if undefined is instance.get name
                # use getter here because property was not defined yet
                instance.set name, def
                saved.push instance unless saved in instance
                # TODO: check value type. 

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
      @["__orig#{name}"] = @[name]?.concat() or [] for name, spec of @type.properties when spec.type is 'array'

    # This method retrieves linked objects in properties.
    # All `object` and `array` properties are resolved. 
    # Properties that aims at unexisting objects are reset to null.
    #
    # @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
    # @option callback err [String] an error message if an error occured.
    # @option callback instance [Object] the root instance on which linked objects were resolved.
    AbstractType.methods.getLinked = (callback) ->
      AbstractType.statics.getLinked [this], (err, instances) =>
        callback err, if instances and instances?.length is 1 then instances[0] else null

    # This static version of `getLinked` performs multiple linked objects resolution in one operation.
    # See `getLinked()` for more information.
    #
    # @param instances [Array<Object>] an array that contains instances which are resoluved.
    # @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
    # @option callback err [String] an error message if an error occured.
    # @option callback instances [Array<Object>] the instances on which linked objects were resolved.
    AbstractType.statics.getLinked = (instances, callback) ->
      ids = []
      # identify each linked properties 
      for instance in instances
        logger.debug "search linked ids in #{instance.id}"
        # gets the corresponding properties definitions
        properties = instance.type.properties
        for prop, def of properties
          value = instance[prop]
          if def.type is 'object' and 'string' is utils.type value
            # Do not resolve objects that were previously resolved
            logger.debug "found #{value} in property #{prop}"
            ids.push value
          else if def.type is 'array' and value?.length > 0 and _.find(value, (val) -> 'string' is utils.type val)?
            # Do not resolve arrays that were previously resolved
            logger.debug "found #{value} in property #{prop}"
            ids = ids.concat value
      
      # now that we have the linked ids, get the corresponding instances.
      return callback(null, instances) unless ids.length > 0

      # resolve in both items and events
      linked = []
      async.forEach [require('./Item'), require('./Event')], (clazz, end) ->
        # do NOT use findCached: triggers a max call stack exceeded
        clazz.find _id: $in:ids, (err, results) ->
          return callback("Unable to resolve linked on #{instances}. Error while retrieving linked: #{err}") if err?
          linked = linked.concat results
          end()
      , ->
        # process again each properties to replace ids with real objects, and remove unknown ids
        for instance in instances
          properties = instance.type.properties
          logger.debug "replace linked ids in #{instance.id}"
          for prop, def of properties
            value = instance[prop]
            if def.type is 'object' and 'string' is utils.type value
              link = null
              for l in linked
                if l.id is value
                  link = l
                  break
              logger.debug "replace with object #{link?.id} in property #{prop}"
              # do not use setter to avoid marking the instance as modified.
              instance._doc[prop] = link
            else if def.type is 'array' and value?.length > 0
              result = []
              for id, i in value when 'string' is utils.type id
                result[i] = _.find linked, (link) -> link.id is id
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
      properties = @type.properties
      # get through all existing attributes
      attrs = Object.keys @_doc;
      for attr in attrs when attr isnt '__v' # ignore versionning attribute
        # remove original saved of dynamic arrays
        if 0 is attr.indexOf '__orig'
          delete @_doc[attr]
          continue
        # not in schema, nor in type
        if attr of properties
          # use not property cause it's not always defined at this moment
          err = modelUtils.checkPropertyType @_doc[attr], properties[attr] 
          next(new Error "Unable to save instance #{@id}. Property #{attr}: #{err}") if err?
        else unless attr of AbstractType.paths
          next new Error "Unable to save instance #{@id}: unknown property #{attr}"

      # set the default values
      for prop, value of properties

        if undefined is @[prop]
          @[prop] = if value.type is 'array' then [] else if value.type is 'object' then null else value.def

        # Do not store strings, store dates instead
        if value.type is 'date' and 'string' is utils.type @[prop]
          @[prop] = new Date @[prop]

      wasNew = @isNew
      ## generate id if necessary
      @id = new ObjectId().toString() unless @id? or !wasNew
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
      modelUtils.processLinks this, properties
      # replace type with its id, for storing in Mongo, without using setters.
      saveType = @type
      @_doc.type = saveType?.id
      next()
      # for each array property, add a save with linked ids to allow further comparisons
      for name, spec of saveType.properties when spec.type is 'array'
        @["__orig#{name}"] = @_doc[name]?.concat() or []
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
      @id = new ObjectId().toString() unless @id? or !wasNew
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