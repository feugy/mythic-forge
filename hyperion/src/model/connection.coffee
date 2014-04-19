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
async = require 'async'
MongoClient = require('mongodb').MongoClient
utils = require '../util/common'
logger = require('../util/logger').getLogger 'model'

# Connect to the 'mythic-forge' database. Will be created if necessary.
# The connection is exported.
if process.env.MONGOHQ_URL?
  url = process.env.MONGOHQ_URL
  db = "mongoHQ"
else
  host = utils.confKey 'mongo.host', 'localhost'
  port = utils.confKey 'mongo.port', 27017
  db = utils.confKey 'mongo.db' 
  user = utils.confKey('mongo.user', null)
  pass = utils.confKey('mongo.password', null)
  url = "mongodb://#{if user? and pass? then "#{user}:#{pass}@" else ''}#{host}:#{port}/#{db}" 

# load ids of all existing models from database

# exports the connection
module.exports = mongoose.createConnection url, {}, (err) ->
  throw new Error "Unable to connect to MongoDB: #{err}" if err?
  logger.info "Connection established with MongoDB on database #{db}"

# opens a dedicated connection to load all table ids.
# connection is immediately closed afterward.
# If no callback is provided, errors will be raised.
#
# @param idCach [Object] object in which ids are stored (as key) with value 1
# @param callback  [Function] invoked when finished with error as first argument (or null otherwise)
module.exports.loadIdCache = (idCache, callback = null) ->
  unless process.env.MONGOHQ_URL?
    url = "mongodb://#{host}:#{port}/#{db}" 

  MongoClient.connect url, (err, db) ->
    if err?
      err = new Error "Failed to connect to mongo to get ids: #{err}" 
      if callback? then callback err else throw err
    # get ids in each collections
    async.forEach ['players', 'items', 'itemtypes', 'events', 'eventtypes', 'maps', 'fieldtypes', 'clientconfs'], (name, next) ->
      db.collection(name).find({},fields: _id:1).toArray (err, results) ->
        return next err if err?
        idCache[obj._id] = 1 for obj in results
        next()
    , (err) ->
      throw new Error "Failed to retrieve ids of collection #{name}: #{err}" if err? and not callback?
      # end the connection
      db.close()
      if err?
        err = new Error "Failed to retrieve ids: #{err}" 
        throw err unless callback?
      callback?(err)
