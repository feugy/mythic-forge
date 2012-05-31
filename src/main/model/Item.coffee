mongoose = require 'mongoose'
conn = require '../dao/connection'
ItemType = require './ItemType'
Map = require './Map'
modelWatcher = require('./ModelWatcher').get()
logger = require('../logger').getLogger 'model'

# We use the post-save middleware to propagate creation and saves.
# But within this function, all instances have lost their "isNew" status
# thus we store that status from the pre-save middleware, to use it in the post-save
# middleware 
wasNew = {}
modifiedPaths = {}

# Define the schema for map items
# Do not use strict schema, because ItemType will add dynamic fields, and will because
# we manually check the field existence with the save middleware.
ItemSchema = new mongoose.Schema({
    # link to map
    map: {}
    x: 
      type: Number
      default: null
    y: 
      type: Number
      default: null
    imageNum: 
      type: Number
      default: 0
    # link to type
    type: 
      type: {}
      required: true
  }, {strict:false})

# Override the equals() method defined in Document, to check correctly the equality between _ids, 
# with their `equals()` method and not with the strict equality operator.
#
# @param other [Object] other object against which the current object is compared
# @return true if both objects have the same _id, false otherwise
ItemSchema.methods.equals = (object) ->
  @_id.equals object?._id

# This method retrieves linked Item in properties.
# All `object` and `array` properties are resolved. 
# Properties that aims at unexisting items are reset to null.
#
# @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
# @option callback err [String] an error message if an error occured.
# @option callback item [Item] the root item on which linked items were resolved.
ItemSchema.methods.resolve = (callback) ->
  ItemSchema.statics.multiResolve [this], (err, items) =>
    result = null
    if items and items?.length is 1
      result = items[0]
    callback err, result

# This static version of resolve performs multiple linked items resolution in one operation.
# See resolve() for more information.
#
# @param items [Array<Item>] an array that contains items which are resoluved.
# @param callback [Function] callback invoked when all linked objects where resolved. Takes two parameters
# @option callback err [String] an error message if an error occured.
# @option callback items [Array<Item>] the items on which linked items were resolved.
ItemSchema.statics.multiResolve = (items, callback) ->
  ids = []
  # identify each linked properties 
  for item in items
    logger.debug "search linked ids in item #{item._id}"
    # gets the corresponding properties definitions
    properties = item.type.get 'properties'
    for prop, def of properties
      value = item.get(prop)
      if def.type is 'object' and typeof value is 'string'
        # Do not resolve objects that were previously resolved
        logger.debug "found #{value} in property #{prop}"
        ids.push value
      else if def.type is 'array' and value?.length > 0 and typeof value[0] is 'string'
        # Do not resolve arrays that were previously resolved
        logger.debug "found #{value} in property #{prop}"
        ids = ids.concat value
  
  # now that we have the linked ids, get the corresponding items.
  return callback(null, items) unless ids.length > 0

  Item.find {_id: {$in: ids}}, (err, linked) ->
    return callback("Unable to resolve linked on #{items}. Error while retrieving linked: #{err}") if err?
    
    # process again each properties to replace ObjectIds with real objects, and remove unknown ids
    for item in items
      properties = item.type.get 'properties'
      logger.debug "replace linked ids in item #{item._id}"
      for prop, def of properties
        value = item.get(prop)
        if def.type is 'object' and typeof value is 'string'
          link = null
          for l in linked
            if l._id.equals value
              link = l
              break
          logger.debug "replace with object #{link?._id} in property #{prop}"
          # do not use setter to avoid marking the instance as modified.
          item._doc[prop] = link
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
    callback null, items

# checkType() enforce that a property value does not violate its corresponding definition.
#
# @param value [Object] the checked value.
# @param property [Object] the property definition
# @option property type [String] the awaited type. Could be: string, text, boolean, integer, float, date, array or object
# @option property def [Object] the default value. For array and objects, indicate the class of the awaited linked objects.
ItemSchema.statics.checkType = (value,  property) ->
  err = null

  # string and text: null or typeof is string
  checkString = ->
    err = "#{value} isn't a valid string" unless value is null or 
      typeof value is 'string'

  # object: null or object with a __proto__ that have the good name.    
  checkObject = (val, isArray) ->
    err = "#{value} isn't a valid #{property.def}" if val isnt null and 
      (typeof val isnt 'object' or val?.collection?.name isnt property.def.toLowerCase()+'s')

  switch property.type 
    # integer: null or float = int value of a number/object
    when 'integer' then err = "#{value} isn't a valid integer" unless value is null or 
      ((typeof value is 'number' or typeof value is 'object') and 
      parseFloat(value, 10) is parseInt(value, 10))
    # foat: null or float value of a number/object
    when 'float' then err = "#{value} isn't a valid float" unless value is null or 
      ((typeof value is 'number' or typeof value is 'object') and not 
      isNaN parseFloat(value, 10))
    # boolean: null or value is false or true and not a string
    when 'boolean' 
      strVal = "#{value}".toLowerCase()
      err = "#{value} isn't a valid boolean" if value isnt null and
        (typeof value is 'string' or 
        (strVal isnt 'true' and strVal isnt 'false'))
    # date : null or typeof is date
    when 'date' then err = "#{value} isn't a valid date" unless value is null or 
      value instanceof Date
    when 'object' then checkObject(value, false)
    # array: array that contains object at each index.
    when 'array'
      if value instanceof Array 
        checkObject obj for obj in value
      else 
        err = "#{value} isn't a valid array of #{property.def}"
    when 'string' then checkString()
    when 'text' then checkString()
    else err = "#{property.type} isn't a valid type"
  err

# Walk through properties and replace linked object with their ids if necessary
#
# @param item [Item] the processed item
# @param properties [Object] the propertes definition, a map index with property names and that contains for each property:
# @option properties type [String] the awaited type. Could be: string, text, boolean, integer, float, date, array or object
# @option properties def [Object] the default value. For array and objects, indicate the class of the awaited linked objects.
processLinks = (item, properties) ->
  for name, property of properties
    value = item.get name
    if property.type is 'object'
      item.set(name, value._id.toString()) if value isnt null and typeof value is 'object' and '_id' of value
    else if property.type is 'array'
      if value
        for linked, i in value
          value[i] = if typeof linked is 'object' and '_id' of linked then linked._id.toString() else linked
        
# pre-save middleware: enforce the existence of each property. 
# Could be declared in the schema, or in the type's properties
# Inside the middleware, `this` aims at the saved item.
#
# @param next [Function] function that must be called to proceed with other middleware.
# Calling it with an argument indicates the the validation failed and cancel the item save.
ItemSchema.pre 'save', (next) ->
  properties = @type.get 'properties'
  # get through all existing attributes
  attrs = Object.keys @_doc;
  for attr in attrs
    # not in schema, nor in type
    if attr of properties
      err = Item.checkType @get(attr), properties[attr] 
      next(new Error "Unable to save item #{@_id}. Property #{attr}: #{err}") if err?
    else unless attr of ItemSchema.paths
      next new Error "Unable to save item #{@_id}: unknown property #{attr}"

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
  saveMap = @map
  @_doc.type = saveType?._id
  @_doc.map = saveMap?._id
  next()
  # restore save to allow reference reuse.
  @_doc.type = saveType
  @_doc.map = saveMap

# post-save middleware: now that the instance was properly saved, propagate its modifications
#
ItemSchema.post 'save', () ->
  modelWatcher.change (if wasNew[@_id] then 'creation' else 'update'), 'Item', this, modifiedPaths[@_id]

# post-remove middleware: now that the instace was properly removed, propagate the removal.
#
ItemSchema.post 'remove', () ->
  modelWatcher.change 'deletion', 'Item', this

# pre-init middleware: retrieve the type corresponding to the stored id.
#
# @param item [Item] the initialized item.
# @param next [Function] function that must be called to proceed with other middleware.
# Calling it with an argument indicates the the validation failed and cancel the item save.
ItemSchema.pre 'init', (next, item) ->
  # loads the type from local cache
  ItemType.findCached item.type, (err, type) ->
    return next(new Error "Unable to init item #{item._id}. Error while resolving its type: #{err}") if err?
    return next(new Error "Unable to init item #{item._id} because there is no type with id #{item.type}") unless type?    
    # Do the replacement.
    item.type = type
    next() unless item.map?
    Map.findCached item.map, (err, map) ->
      return next(new Error "Unable to init item #{item._id}. Error while resolving its map: #{err}") if err?
      return next(new Error "Unable to init item #{item._id} because there is no map with id #{item.map}") unless map?    
      # Do the replacement.
      item.map = map
      next()


# Export the Class.
Item = conn.model 'item', ItemSchema
module.exports = Item