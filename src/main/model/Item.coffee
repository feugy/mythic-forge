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

# save middleware: enforce the existence of each property. 
# Could be declared in the schema, or in the type's properties
ItemSchema.pre 'save', (next) ->
  item = this
  # loads the type
  ItemType.findOne {_id: item.typeId}, (err, type) ->
    next(new Error "Unable to save item #{item._id}. Error while resolving its type: #{err}") if err?
    next(new Error "Unable to save item #{item._id} because there is no type with id #{item.typeId}") unless type?
    # get through all existing attributes
    attrs = Object.keys item._doc;
    for attr in attrs
      # not in schema, nor in type
      next(new Error "Unable to save item #{item._id}: unknown property #{attr}") unless attr of ItemSchema.paths or 
        attr of type.get 'properties'
    # set the default values
    for prop, value of type.get 'properties'
      item.set(prop, value.def) if undefined is item.get prop
    next()

# Export the Class.
module.exports = conn.model 'item', ItemSchema