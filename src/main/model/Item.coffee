mongoose = require 'mongoose'
conn = require '../dao/connection'

ObjectID = mongoose.Schema.ObjectId

# Define the schema for map items
Item = conn.model 'item', new mongoose.Schema
  uid: ObjectID
  map: ObjectID
  x: Number
  y: Number
  imageNum: Number
  type: ObjectID

# Export the Class.
module.exports = Item