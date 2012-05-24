logger = require('../logger').getLogger 'web'
express = require 'express'
gameService = require('../service/GameService').get()
path = require 'path'
fs = require 'fs'
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

# socket.io `game` namespace 
#
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

# socket.io `updates` namespace 
#
# 'updates' namespace will broadcast all modifications on the database.
# The event name will be 'creation', 'update' or 'deletion', and as parameter,
# the concerned instance (only the modified parts for an update)
#
# @see {ModelWatcher.change}
updateNS = io.of('/updates')

watcher.on 'change', (operation, instance) ->
  logger.debug "broadcast of #{operation} on #{instance._id}"
  updateNS.emit operation, instance

# on-the-fly express compilation and static file configuration
publicFolder = path.join __dirname, '../../../src/game'
app.use express.compiler
    src: publicFolder,
    dest: publicFolder,
    enable: ['coffeescript']
# js files will be statically served...
app.use '/js', express.static path.join publicFolder, 'js'
# ...but SPA root need to be treaten differently, because of pushState
app.get '*', (req, res, next) ->
  if req.url.indexOf('/js') is 0
    return next()
  console.log 'serve root'
  fs.createReadStream(path.join(publicFolder, 'index.html')).pipe res

# Exports the application.
module.exports = app
