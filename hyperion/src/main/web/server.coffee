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

logger = require('../logger').getLogger 'web'
express = require 'express'
utils = require '../utils'
http = require 'http'
https = require 'https'
fs = require 'fs'
passport = require 'passport'
GoogleStrategy = require('passport-google-oauth').OAuth2Strategy
gameService = require('../service/GameService').get()
playerService = require('../service/PlayerService').get()
adminService = require('../service/AdminService').get()
imagesService = require('../service/ImagesService').get()
searchService = require('../service/SearchService').get()
authoringService = require('../service/AuthoringService').get()
watcher = require('../model/ModelWatcher').get()

# If an ssl certificate is found, use it.
app = null
certPath = utils.confKey 'ssl.certificate', null
keyPath = utils.confKey 'ssl.key', null
app = express() 
app.use passport.initialize()
if certPath? and keyPath?
  caPath = utils.confKey 'ssl.ca', null
  logger.info "use SSL certificates: #{certPath}, #{keyPath} and #{if caPath? then caPath else 'no certificate chain'}"
  # Creates the server with SSL certificates
  opt = 
    cert: fs.readFileSync(certPath).toString()
    key: fs.readFileSync(keyPath).toString()
  opt.ca = fs.readFileSync(caPath).toString() if caPath?
  server = https.createServer opt, app
else 
  # Creates a plain web server
  server = http.createServer app

# Configure socket.io with it
io = require('socket.io').listen server, {logger: logger}

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
# @param except [Array] optionnal array of ignored method. dafault to empty array
exposeMethods = (service, socket, except = []) ->
  # exposes all methods
  for method of service.__proto__ 
    unless method in except
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
# 'game' namespace exposes all method of GameService, plus a special 'currentPlayer' method.
# @see {GameService}
io.of('/game').on 'connection', (socket) ->
  exposeMethods gameService, socket

# socket.io `admin` namespace 
#
# configure the differents message allowed
# 'admin' namespace is associated to AdminService, ImageService, AuthoringService and SearchService
# @see {AdminService}
io.of('/admin').on 'connection', (socket) ->
  exposeMethods adminService, socket
  exposeMethods imagesService, socket
  exposeMethods searchService, socket
  exposeMethods authoringService, socket, ['readRoot', 'save', 'remove']

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

# Authentication: 
# Configure a passport strategy to use Google's Oauth2 mechanism.
# Browser will be redirected to success Url with a `token` parameter in case of success 
# Browser will be redirected to success Url with a `err` parameter in case of failure
successUrl = utils.confKey 'authentication.success'
errorUrl = utils.confKey 'authentication.error'

passport.use new GoogleStrategy
    clientID: utils.confKey 'authentication.google.id'
    clientSecret: utils.confKey 'authentication.google.secret'
    callbackURL: "#{if certPath? then 'https' else 'http'}://#{utils.confKey 'server.host'}:#{utils.confKey 'server.apiPort'}/auth/google/callback"
  , playerService.authenticatedFromGoogle
 
# `GET /auth/google`
#
# The authentication API with google. Will redirect browser to google authentication page.
# Once authenticated, browser is redirected on mythic-forge
app.get '/auth/google', passport.authenticate 'google', 
  session: false
  scope: ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email']

# `GET /auth/google/google`
#
# The authentication callback used by Google. Redirect the browser with the connexion token to configured url.
# The connexion token is needed to establish the soket.io handshake.
app.get '/auth/google/callback', (req, res, next) ->
  passport.authenticate('google', (err, token) ->
    # authentication failed
    return res.redirect "#{errorUrl}error=#{err}" if err?
    res.redirect "#{successUrl}token=#{token}"
  )(req, res, next)

# Authorization (disabled for tests):
# Once authenticated, a user has been returned a authorization token.
# this token is used to allow to connect with socket.io. 
# **TODO** For administraction namespaces, the user rights are to be checked also.
unless process.env.NODE_ENV is 'test'

  io.configure -> io.set 'authorization', (handshakeData, callback) ->
    # check if a token has been sent
    token = handshakeData.query.token
    return callback 'No token provided' if 'string' isnt utils.type(token) or token.length is 0

    # then identifies player with this token
    playerService.getByToken token, (err, player) ->
      return callback err if err?
      # if player exists, authorization awarded !
      if player?
        logger.info "Player #{player.get 'email'} connected with token #{token}"
        # this will allow to store connected player into the socket details
        handshakeData.playerEmail = player.get 'email'
      callback null, player?

  # When a client connects, returns it immediately its token
  io.on 'connection', (socket) ->
    # retrieve the player email set during autorization phase, and stores it.
    socket.set 'email', socket.manager.handshaken[socket.id]?.playerEmail

    # special message to get connected player
    socket.on 'getConnected', (callback) ->
      socket.get 'email', (err, value) ->
        return callback err if err?
        playerService.getByEmail value, callback

# Exports the application.
module.exports = server
