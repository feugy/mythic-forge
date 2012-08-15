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
utils = require '../utils'
fs = require 'fs'
path = require 'path'
async = require 'async'
modelWatcher = require('./ModelWatcher').get()
imageStore = require('../utils').confKey('images.store')
logger = require('../logger').getLogger 'model'

# Walk through properties and replace linked object with their ids if necessary
#
# @param instance [Object] the processed instance
# @param properties [Object] the propertes definition, a map index with property names and that contains for each property:
# @option properties type [String] the awaited type. Could be: string, text, boolean, integer, float, date, array or object
# @option properties def [Object] the default value. For array and objects, indicate the class of the awaited linked objects.
processLinks = (instance, properties) ->
  for name, property of properties
    value = instance.get name
    if property.type is 'object'
      instance.set(name, value._id.toString()) if value isnt null and typeof value is 'object' and '_id' of value
    else if property.type is 'array'
      if value
        for linked, i in value
          value[i] = if typeof linked is 'object' and '_id' of linked then linked._id.toString() else linked

# Factory that creates an abstract type.
# Provides:
# - `name` and `desc` i18n attributes
# - id-based `equals` method
# - modelWatcher usage
# - cache functionnalities and `findCached` static method
# - image storage with `saveImage`and `removeImage`
# - properties management, for type or instances
#
# @param typeName [String] name of the build type, used for changes propagations
# @param attrs [Object] attributes of the created type.
# @param options [Object] Mongoose schema options, and factory custom options:
# @option options noName [Boolean] wether this type has a name or not.
# @option options noDesc [Boolean] wether this type has a description or not.
# @option options noCache [Boolean] wether objects of this type are cached or not.
# @option options typeProperties [Boolean] wether this type will defined properties for its instances
# @option options instanceClass [String] if this type has type-properties, the instance class name
# @option options instanceProperties [Boolean] wether this type will embed properties
# @option options typeClass [Object] if this type has instance-properties, the type class name
module.exports = (typeName, spec, options = {}) ->

  # Local cache
  cache = {}

  # We use the post-save middleware to propagate creation and saves.
  # But within this function, all instances have lost their "isNew" status
  # thus we store that status from the pre-save middleware, to use it in the post-save
  # middleware 
  wasNew = {}
  modifiedPaths = {}

  if options?.typeProperties
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

  if options?.instanceProperties
    # link to type, mandatory to retrieve properties definitions
    spec.type = 
      type: {}
      required: true

  # Abstract schema, that can contains i18n attributes
  AbstractType = new mongoose.Schema spec, options

  utils.enhanceI18n AbstractType

  unless options?.noName
    # Adds an i18n `name` field which is required
    utils.addI18n AbstractType, 'name', {required: true}

  unless options?.noDesc
    # Adds an i18n `desc` field
    utils.addI18n AbstractType, 'desc'

  # Override the equals() method defined in Document, to check correctly the equality between _ids, 
  # with their `equals()` method and not with the strict equality operator.
  #
  # @param other [Object] other object against which the current object is compared
  # @return true if both objects have the same _id, false otherwise
  AbstractType.methods.equals = (object) ->
    @_id.equals object?._id

  unless options?.noCache
    # This special finder maintains an in-memory cache of types, to faster type retrieval by ids.
    # If the id isn't found in cache, search in database.
    #
    # @param id [String] the type id.
    # @param callback [Function] the callback function, that takes two parameters
    # @option callback err [String] an error string, or null if no error occured
    # @option callback type [Type] the found type, or null if no type found for the id
    AbstractType.statics.findCached = (id, callback) ->
      # first look in the cache
      return callback null, cache[id] if id of cache
      # nothing in the cache: search in database
      @findOne {_id: id}, callback

    # post-init middleware: populate the cache
    AbstractType.post 'init', ->
      # store in cache
      cache[@_id] = @
  
  # pre-save middleware: store modified path for changes propagation
  AbstractType.pre 'save', (next) ->
    # stores the isNew status and modified paths.
    wasNew[@_id] = @isNew
    modifiedPaths[@_id] = @modifiedPaths.concat()
    next()

  # post-save middleware: now that the instance was properly saved, update the cache.
  AbstractType.post 'save', ->
    # updates the cache
    cache[@_id] = @ unless options?.noCache
    modelWatcher.change (if wasNew[@_id] then 'creation' else 'update'), typeName, this, modifiedPaths[@_id]
    
  # post-remove middleware: now that the type was properly removed, update the cache.
  AbstractType.post 'remove', ->
    # updates the cache
    delete cache[@_id] unless options?.noCache
    # broadcast deletion
    modelWatcher.change 'deletion', typeName, this

  # post-remove middleware: removes images, without using the ImageService
  AbstractType.post 'remove', ->
    # removes all images that starts with the id from the image store.
    id = @_id
    fs.readdir imageStore, (err, files) ->
      for file in files when file.indexOf("#{id}-") is 0
        fs.unlink path.join imageStore, file

  if options?.typeProperties

    # setProperty() adds or updates a property.
    #
    # @param name [String] the unic name of the property.
    # @param type [String] primitive type of the property's values. Could be: string, text, boolean, integer, float, date, array or object
    # @param def [Object] default value affected to the type instances.
    AbstractType.methods.setProperty = (name, type, def) ->
      @get('properties')[name] = {type: type, def: def}
      @markModified 'properties'
      @_updatedProps = [] unless @_updatedProps?
      @_updatedProps.push name

    # unsetProperty() removes a property. All existing instances loose their own property value.
    # Will throw an error if the property does not exists.
    #
    # @param name [String] the unic name of the property.
    AbstractType.methods.unsetProperty = (name) ->
      throw new Error "Unknown property #{name} for type #{@name}" unless @get('properties')[name]?
      delete @get('properties')[name]
      @markModified 'properties'
      @_deletedProps = [] unless @_deletedProps?
      @_deletedProps.push name

    # pre-save middleware: update type instances' properties if needed.
    AbstractType.pre 'save', (next) ->
      return next() unless @_updatedProps? or @_deletedProps?
      
      # get type instances
      require("./#{options.instanceClass}").find {type: @_id}, (err, instances) =>
        saved = []
        for instance in instances
          # add default value in instances that do not have the added properties yet.
          if @_updatedProps?
            for name in @_updatedProps
              prop = @get('properties')[name]
              def = prop.def
              switch prop.type
                when 'array' then def = []
                when 'object' then def = null

              if not(name of instance)
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
        async.forEach saved, ((instance, done) -> instance.save done), next

  if options?.instanceProperties

    # pre-init middleware: retrieve the type corresponding to the stored id.
    #
    # @param instance [Object] the initialized instance.
    # @param next [Function] function that must be called to proceed with other middleware.
    # Calling it with an argument indicates the the validation failed and cancel the instance save.
    AbstractType.pre 'init', (next, instance) ->
      # loads the type from local cache
      require("./#{options.typeClass}").findCached instance.type, (err, type) ->
        return next(new Error "Unable to init instance #{instance._id}. Error while resolving its type: #{err}") if err?
        return next(new Error "Unable to init instance #{instance._id} because there is no type with id #{instance.type}") unless type?    
        # Do the replacement.
        instance.type = type
        next()

    # This method retrieves linked objects in properties.
    # All `object` and `array` properties are resolved. 
    # Properties that aims at unexisting objects are reset to null.
    #
    # @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
    # @option callback err [String] an error message if an error occured.
    # @option callback instance [Object] the root instance on which linked objects were resolved.
    AbstractType.methods.resolve = (callback) ->
      AbstractType.statics.multiResolve [this], (err, instances) =>
        result = null
        if instances and instances?.length is 1
          result = instances[0]
        callback err, result

    # This static version of resolve performs multiple linked objects resolution in one operation.
    # See resolve() for more information.
    #
    # @param instances [Array<Object>] an array that contains instances which are resoluved.
    # @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
    # @option callback err [String] an error message if an error occured.
    # @option callback instances [Array<Object>] the instances on which linked objects were resolved.
    AbstractType.statics.multiResolve = (instances, callback) ->
      ids = []
      # identify each linked properties 
      for instance in instances
        logger.debug "search linked ids in #{instance._id}"
        # gets the corresponding properties definitions
        properties = instance.type.get 'properties'
        for prop, def of properties
          value = instance.get(prop)
          if def.type is 'object' and typeof value is 'string'
            # Do not resolve objects that were previously resolved
            logger.debug "found #{value} in property #{prop}"
            ids.push value
          else if def.type is 'array' and value?.length > 0 and typeof value[0] is 'string'
            # Do not resolve arrays that were previously resolved
            logger.debug "found #{value} in property #{prop}"
            ids = ids.concat value
      
      # now that we have the linked ids, get the corresponding instances.
      return callback(null, instances) unless ids.length > 0

      # resolve in both items and events
      linked = []
      async.forEach [require('./Item'), require('./Event')], (clazz, end) ->
        clazz.find {_id: {$in: ids}}, (err, results) ->
          return callback("Unable to resolve linked on #{instances}. Error while retrieving linked: #{err}") if err?
          linked = linked.concat results
          end()
      , ->
        # process again each properties to replace ObjectIds with real objects, and remove unknown ids
        for instance in instances
          properties = instance.type.get 'properties'
          logger.debug "replace linked ids in #{instance._id}"
          for prop, def of properties
            value = instance.get(prop)
            if def.type is 'object' and typeof value is 'string'
              link = null
              for l in linked
                if l._id.equals value
                  link = l
                  break
              logger.debug "replace with object #{link?._id} in property #{prop}"
              # do not use setter to avoid marking the instance as modified.
              instance._doc[prop] = link
            else if def.type is 'array' and value?.length > 0 and typeof value[0] is 'string'
              for id, i in value
                link = null
                for l in linked
                  if l._id.equals id
                    link = l
                    break
                # do not use setter to avoid marking the instance as modified.
                logger.debug "replace with object #{link?._id} position #{i} in property #{prop}"
                value[i] = link
        # done !
        callback null, instances
      
    # pre-save middleware: enforce the existence of each property. 
    # Could be declared in the schema, or in the type's properties
    # Inside the middleware, `this` aims at the saved instance.
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    # Calling it with an argument indicates the the validation failed and cancel the instante save.
    AbstractType.pre 'save', (next) ->
      properties = @type.get 'properties'
      # get through all existing attributes
      attrs = Object.keys @_doc;
      for attr in attrs
        # not in schema, nor in type
        if attr of properties
          err = utils.checkPropertyType @get(attr), properties[attr] 
          next(new Error "Unable to save instance #{@_id}. Property #{attr}: #{err}") if err?
        else unless attr of AbstractType.paths
          next new Error "Unable to save instance #{@_id}: unknown property #{attr}"

      # set the default values
      for prop, value of @type.get 'properties'
        if undefined is @get prop
          @set prop, if value.type is 'array' then [] else if value.type is 'object' then null else value.def

      # stores the isNew status.
      wasNew[@_id] = @isNew
      modifiedPaths[@_id] = @modifiedPaths.concat()

      # replace links by them _ids
      processLinks this, properties
      # replace type with its id, for storing in Mongo, without using setters.
      saveType = @type
      @_doc.type = saveType?._id
      next()
      # restore save to allow reference reuse.
      @_doc.type = saveType

  return AbstractType