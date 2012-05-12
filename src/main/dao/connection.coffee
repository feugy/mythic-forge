mongoose = require 'mongoose'

# Connect to the 'mythic-forge' database. Will be created if necessary.
# The connection is exported.
module.exports = mongoose.createConnection 'mongodb://localhost/mythic-forge'