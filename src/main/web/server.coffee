logger = require('../logger').getLogger 'web'
express = require 'express'
gameService = require('../service/GameService').get()
# creates a single server, and configure socket.io with it.
app = express.createServer()
io = require('socket.io').listen app, {logger: logger}
watcher = require('../model/ModelWatcher').get()

# `GET /konami`
#
# Just a fun test page to ensure the server is running.
# Responds the conami code in a `<pre>` HTML markup
app.get '/konami', (req, res) ->
  res.send '<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>'

# configure the differents message allowed
# 'game' namespace is associated to GameService
# @see {GameService.consultMap}
io.of('/game').on 'connection', (socket) ->
  # exposes all gameService methods
  for method of gameService.__proto__
    do(method) ->
      socket.on method, ->
        # add return callback to incoming arguments
        originalArgs = Array.prototype.slice.call arguments
        args = originalArgs.concat()
        args.push ->
          logger.debug "returning #{method} response #{if arguments[0]? then arguments[0] else ''}"
          # returns the callback arguments
          returnArgs = Array.prototype.slice.call arguments
          returnArgs.splice 0, 0, "#{method}-resp"
          socket.emit.apply socket, returnArgs

        # invoke the service layer with arguments 
        logger.debug "processing #{method} message with arguments #{originalArgs}"
        gameService[method].apply gameService, args

# 'updates' namespace will broadcast all modifications on the database.
# The event name will be 'creation', 'update' or 'deletion', and as parameter,
# the concerned instance (only the modified parts for an update)
#
# @see {ModelWatcher.change}
updateNS = io.of('/updates')

watcher.on 'change', (operation, instance) ->
  logger.debug "broadcast of #{operation} on #{instance._id}"
  updateNS.emit operation, instance

# Exports the application.
module.exports = app
