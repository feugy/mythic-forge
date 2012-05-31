mongoose = require 'mongoose'
conn = require '../dao/connection'
modelWatcher = require('./ModelWatcher').get()
logger = require('../logger').getLogger 'model'

# Define the schema for players
PlayerSchema = new mongoose.Schema
  # no password for now.
  login: 
    type: String 
    required: true

  lastConnection: Date
  
  # link to the character.
  characterId:
    type: mongoose.Schema.ObjectId
    default: null


# We use the post-save middleware to propagate creation and saves.
# But within this function, all instances have lost their "isNew" status
# thus we store that status from the pre-save middleware, to use it in the post-save
# middleware 
wasNew = {}
modifiedPaths = {}

# pre-save middleware: store modified paths to allow their propagation
#
# @param next [Function] function that must be called to proceed with other middleware.
PlayerSchema.pre 'save', (next) ->
  # stores the isNew status.
  wasNew[@_id] = @isNew
  modifiedPaths[@_id] = @modifiedPaths.concat()
  next()

# post-save middleware: now that the instance was properly saved, propagate its modifications
#
PlayerSchema.post 'save', () ->
  modelWatcher.change (if wasNew[@_id] then 'creation' else 'update'), 'Player', this, modifiedPaths[@_id]

# post-remove middleware: now that the instace was properly removed, propagate the removal.
#
PlayerSchema.post 'remove', () ->
  modelWatcher.change 'deletion', 'Player', this

# Export the Class.
Player = conn.model 'player', PlayerSchema
module.exports = Player