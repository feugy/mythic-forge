mongoose = require 'mongoose'
utils = require '../utils'

host = utils.confKey 'mongo.host', 'localhost'
port = utils.confKey 'mongo.port', 27017
db = utils.confKey 'mongo.db' 

# Connect to the 'mythic-forge' database. Will be created if necessary.
# The connection is exported.
module.exports = mongoose.createConnection "mongodb://#{host}:#{port}/#{db}"