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
###

logger = require('../logger').getLogger 'web'
express = require 'express'
utils = require '../utils'
fs = require 'fs'
gameService = require('../service/GameService').get()
playerService = require('../service/PlayerService').get()
watcher = require('../model/ModelWatcher').get()

# If an ssl certificate is found, use it.
app = null
certPath = utils.confKey 'ssl.certificate', null
keyPath = utils.confKey 'ssl.key', null
if certPath? and keyPath?
  caPath = utils.confKey 'ssl.ca', null
  logger.info "use SSL certificates: #{certPath}, #{keyPath} and #{if caPath? then caPath else 'no certificate chain'}"
  # Creates the server with SSL certificates
  opt = 
    cert: fs.readFileSync(certPath).toString()
    key: fs.readFileSync(keyPath).toString()
  opt.ca = fs.readFileSync(caPath).toString() if caPath?
  app = express.createServer opt
else 
  # Creates a plain web server
  app = express.createServer()

# Configure socket.io with it
io = require('socket.io').listen app, {logger: logger}

# `GET /konami`
#
# Just a fun test page to ensure the server is running.
# Responds the conami code in a `<pre>` HTML markup
app.get '/konami', (req, res) ->
  res.send '<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>'

# This methods exposes all service methods in a given namespace.
#
# @param service [Object] the service instance which is exposed.
# @param socket [Object] the socket namespace that will expose service methods.
exposeMethods = (service, socket) ->
  # exposes all methods
  for method of service.__proto__
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
        service[method].apply service, args

# socket.io `game` namespace 
#
# configure the differents message allowed
# 'game' namespace is associated to GameService
# @see {GameService}
io.of('/game').on 'connection', (socket) ->
  exposeMethods gameService, socket

# socket.io `player` namespace 
#
# configure the differents message allowed
# 'player' namespace is associated to PlayerService
# @see {PlayerService}
io.of('/player').on 'connection', (socket) ->
  exposeMethods playerService, socket

# socket.io `updates` namespace 
#
# 'updates' namespace will broadcast all modifications on the database.
# The event name will be 'creation', 'update' or 'deletion', and as parameter,
# the concerned instance (only the modified parts for an update)
#
# @see {ModelWatcher.change}
updateNS = io.of('/updates')

watcher.on 'change', (operation, className, instance) ->
  logger.debug "broadcast of #{operation} on #{instance._id}"
  updateNS.emit operation, className, instance

# Exports the application.
module.exports = app
