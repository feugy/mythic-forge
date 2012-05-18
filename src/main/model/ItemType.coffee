mongoose = require 'mongoose'
conn = require '../dao/connection'

# Define the schema for map item types
ItemTypeSchema = new mongoose.Schema
  name: {type: String, required: true}
  images: [Number]
  properties: 
    default: {}

# setProperty() adds or updates a property.
#
# @param name [String] the unic name of the property.
# @param type [Object] primitive type of the property's values 
# @param def [Object] default value affected to the type instances.
ItemTypeSchema.methods.setProperty = (name, type, def) ->
  @get('properties')[name] = {type: type, def: def}
  @markModified 'properties'
  switch type
    when 'array' then def = []
    when 'object' then def = null
  # Modifiy instances.
  require('./Item').find {typeId: @_id}, (err, items) =>
    for item in items
      if not(name of item)
        item.set name, def
        item.save (err, saved) =>
          throw new Error "Unable to save item #{item._id} of type #{@_id} while setting property #{name}: #{err}" if err?

# unsetProperty() removes a property. All existing instances loose their own property value.
# Will throw an error if the property does not exists.
#
# @param name [String] the unic name of the property.
ItemTypeSchema.methods.unsetProperty = (name) ->
  throw new Error "Unknown property #{name} for item type #{@name}" unless @get('properties')[name]?
  delete @get('properties')[name]
  @markModified 'properties'
  # Modifiy instances.
  require('./Item').find {typeId: @_id}, (err, items) =>
    for item in items
      item.set name, undefined
      delete item._doc[name]
      item.save (err) =>
        throw new Error "Unable to save item #{item._id} of type #{@_id} while removing property #{name}: #{err}" if err?

# Export the Class.
module.exports = conn.model 'itemType', ItemTypeSchema