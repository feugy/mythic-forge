mongoose = require 'mongoose'
conn = require '../dao/connection'
ItemType = require './ItemType'

ObjectId = mongoose.Schema.ObjectId


# Define the schema for map items
# Do not use strict schema, because ItemType will add dynamic fields, and will because
# we manually check the field existence with the save middleware.
ItemSchema = new mongoose.Schema({
    uid: ObjectId
    mapId: ObjectId
    x: {type: Number, default: null}
    y: {type: Number, default: null}
    imageNum: {type: Number, default: 0}
    typeId: {type: ObjectId, required: true}
  }, {strict:false})

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

# save middleware: enforce the existence of each property. 
# Could be declared in the schema, or in the type's properties
# Inside the middleware, `this` aims at the saved item.
#
# @param next [Function] function that must be called to proceed with other middleware.
# Calling it with an argument indicates the the validation failed and cancel the item save.
ItemSchema.pre 'save', (next) ->
  item = this
  # loads the type
  ItemType.findOne {_id: item.typeId}, (err, type) ->
    next(new Error "Unable to save item #{item._id}. Error while resolving its type: #{err}") if err?
    next(new Error "Unable to save item #{item._id} because there is no type with id #{item.typeId}") unless type?
    properties = type.get 'properties'
    # get through all existing attributes
    attrs = Object.keys item._doc;
    for attr in attrs
      # not in schema, nor in type
      if attr of properties
        err = ItemSchema.statics.checkType item.get(attr), properties[attr] 
        next(new Error "Unable to save item #{item._id}. Property #{attr}: #{err}") if err?
      else unless attr of ItemSchema.paths
        next new Error "Unable to save item #{item._id}: unknown property #{attr}"
      
    # set the default values
    for prop, value of type.get 'properties'
      item.set(prop, value.def) if undefined is item.get prop
    next()

# Export the Class.
module.exports = conn.model 'item', ItemSchema