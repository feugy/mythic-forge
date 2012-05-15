mongoose = require 'mongoose'
conn = require '../dao/connection'

# Define the schema for map item types
ItemTypeSchema = new mongoose.Schema
  name: {type: String, required: true}
  images: [Number]
  properties: 
    type: mongoose.Schema.Types.Mixed
    default: {}
    set: (val) ->
      # because Mongoose do not trace modifications on mixed attributes
      @markModified 'properties'
      val

# setProperty() adds or updates a property.
#
# @param name [String] the unic name of the property.
# @param type [Object] primitive type of the property's values 
# @param def [Object] default value affected to the type instances.
ItemTypeSchema.methods.setProperty = (name, type, def) ->
  @properties[name] = {type: type, def: def}
  @markModified 'properties'
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
  throw new Error "Unknown property #{name} for item type #{@name}" unless @properties[name]?
  delete @properties[name]
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