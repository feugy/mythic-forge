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
mongodb = require 'mongodb'
utils = require '../util/common'
logger = require('../logger').getLogger 'model'

host = utils.confKey 'mongo.host', 'localhost'
port = utils.confKey 'mongo.port', 27017
db = utils.confKey 'mongo.db' 

# Connect to the 'mythic-forge' database. Will be created if necessary.
# The connection is exported.
url = "mongodb://#{host}:#{port}/#{db}"
options = 
  user: utils.confKey('mongo.user', null)
  pass: utils.confKey('mongo.password', null)
delete options.user unless options.user
delete options.pass unless options.pass

# opens the connection
module.exports = mongoose.createConnection url, options, (err) ->
  throw new Error "Unable to connect to MongoDB: #{err}" if err?
  #admin = new mongodb.Admin module.exports.db
  #admin.buildInfo (err, info) ->
  #  console.log ">>>> connection on mongo version #{info.version}", info
  logger.info "Connection established with MongoDB on database #{db}"