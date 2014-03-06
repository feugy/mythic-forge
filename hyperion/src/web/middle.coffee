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

express = require 'express'
_ = require 'underscore'
utils = require '../util/common'
http = require 'http'
https = require 'https'
fs = require 'fs'
passport = require 'passport'
moment = require 'moment'
urlParse = require('url').parse
corser = require 'corser'
GoogleStrategy = require('passport-google-oauth').OAuth2Strategy
TwitterStrategy = require('passport-twitter').Strategy
LocalStrategy = require('passport-local').Strategy
gameService = require('../service/GameService').get()
playerService = require('../service/PlayerService').get()
adminService = require('../service/AdminService').get()
imagesService = require('../service/ImagesService').get()
searchService = require('../service/SearchService').get()
authoringService = require('../service/AuthoringService').get()
deployementService = require('../service/DeployementService').get()
ruleService = require('../service/RuleService').get()
watcher = require('../model/ModelWatcher').get()
notifier = require('../service/Notifier').get()
LoggerFactory = require '../util/logger'

logger = LoggerFactory.getLogger 'web'

# If an ssl certificate is found, use it.
app = null
certPath = utils.confKey 'ssl.certificate', null
keyPath = utils.confKey 'ssl.key', null
app = express() 

noSecurity = process.env.NODE_ENV is 'test'
host = utils.confKey 'server.host'
staticPort = utils.confKey 'server.staticPort', process.env.PORT or ''
bindingPort = utils.confKey 'server.bindingPort', process.env.PORT or ''

app.use express.cookieParser utils.confKey 'server.cookieSecret'
app.use express.urlencoded()
app.use express.json()
app.use express.methodOverride()
app.use corser.create
  origins:[
    "http://#{host}:#{staticPort}"
    "http://#{host}:#{bindingPort}"
  ]
  methods: ['GET', 'HEAD', 'POST', 'DELETE', 'PUT']
app.use express.session secret: 'mythic-forge' # mandatory for OAuth providers
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
io = require('socket.io').listen server, logger: LoggerFactory.getLogger 'webSocket'
io.set 'log level', 0 # only errors

# Returns redirection url after authentication
# Garantee no query parameter, and always redirect on static port without http
#
# @param req [Object] incoming request
# @return string to redirect on
getRedirect = (req) ->
  url = urlParse if req.headers.referer? then req.headers.referer else "http://#{req.headers.host}"
  "http://#{host}:#{bindingPort or staticPort}#{url.pathname}"

# This methods exposes all service methods in a given namespace.
# The first parameter of all mehods is interpreted as a request id, used inside response to allow client to distinguish calls.
#
# @param service [Object] the service instance which is exposed.
# @param socket [Object] the socket namespace that will expose service methods.
# @param connected [Array] optionnal array of method that needs connected email before callback parameter. default to empty array
# @param except [Array] optionnal array of ignored method. default to empty array
exposeMethods = (service, socket, connected = [], except = []) ->
  # Get the connected player email, unless noSecurity specified. In this case, admin is always connected.
  socket.get 'email', (err, email) ->
    email = 'admin' if noSecurity

    # exposes all methods
    for method of service.__proto__ 
      unless method in except
        do(method) ->
          socket.on method, ->
            # reset inactivity
            playerService.activity email
            originalArgs = Array.prototype.slice.call arguments
            args = originalArgs.slice 1
            # first parameter is always request id
            reqId = originalArgs[0]
            
            # add connected email for those who need it.
            args.push email if method in connected

            # add return callback to incoming arguments
            args.push ->
              logger.debug "returning #{method} response #{if arguments[0]? then arguments[0] else ''}"
              # returns the callback arguments
              returnArgs = Array.prototype.slice.call arguments
              # first response parameters are always method name and request id
              returnArgs.splice 0, 0, "#{method}-resp", reqId
              # expand errors
              returnArgs[2] = returnArgs[2].message if utils.isA returnArgs?[2], Error
              socket.emit.apply socket, returnArgs

            # invoke the service layer with arguments 
            logger.debug "processing #{method} message with arguments #{originalArgs}"
            service[method].apply service, args

# Authorization method for namespaces.
# Get the connected player email from handshake data and allow only if player has administration right
#
# @param handshakeData [Object] handshake data. Contains:
# @option handshakeData playerEmail [String] the connected player's email
# @param callback [Function] authorization callback, invoked with two parameters:
# @option callback err [String] an error message, or null if no error occured
# @option callback allowed [Boolean] true to allow access
checkAdmin = (handshakeData, callback) ->
  # always give access for tests
  return callback null, true if noSecurity
  # check connected user rights
  playerService.getByEmail handshakeData?.playerEmail, false, (err, player) ->
    return callback "Failed to consult connected player: #{err}" if err?
    callback null, player?.isAdmin

# Creates routes to allow authentication from an OAuth/OAuth2 provider:
#
# `GET /auth/#{provider}`
#
# The authentication API. Will redirect browser to provider's authentication page.
# Once authenticated, prodiver will redirect browser to callback utel
#
# `GET /auth/#{provider}/google`
#
# The authentication callback used by provider. Redirect the browser with the connexion token to configured url.
# The connexion token is needed to establish the soket.io handshake.
#
# @param provider [String] the provider name, lower case, used in url and as strategy name.
# @param strategy [Passport.Strategy] the strategy class involved
# @param verify [Function] Function used to enroll users from provider's response.
# @param scopes [Array] OAuth2 scopes sent to provider. Null for OAuth providers
registerOAuthProvider = (provider, strategy, verify, scopes = null) ->

  if scopes?
    # OAuth2 provider
    passport.use new strategy
      clientID: utils.confKey "authentication.#{provider}.id"
      clientSecret: utils.confKey "authentication.#{provider}.secret"
      callbackURL: "#{if certPath? then 'https' else 'http'}://#{utils.confKey 'server.host'}:#{utils.confKey 'server.bindingPort', utils.confKey 'server.apiPort'}/auth/#{provider}/callback"
    , verify

    args = session: false, scope: scopes

  else
    # OAuth provider
    passport.use new strategy
      consumerKey: utils.confKey "authentication.#{provider}.id"
      consumerSecret: utils.confKey "authentication.#{provider}.secret"
      callbackURL: "#{if certPath? then 'https' else 'http'}://#{utils.confKey 'server.host'}:#{utils.confKey 'server.bindingPort', utils.confKey 'server.apiPort'}/auth/#{provider}/callback"
    , verify

    args = {}

  redirects = []

  app.get "/auth/#{provider}", (req, res, next) ->
    # store redirection url
    id = "req#{_.uniqueId()}"
    redirects[id] = getRedirect req
    if scopes?
      args.state = id
    else 
      req.session.state = id
    passport.authenticate(provider, args) req, res, next

  app.get "/auth/#{provider}/callback", (req, res, next) ->
    # reuse redirection url
    if scopes?
      state = req.param 'state'
    else
      state = req.session.state
    redirect = redirects[state]
    
    passport.authenticate(provider, (err, token) ->
      # authentication failed
      return res.redirect "#{redirect}?error=#{err}" if err?
      res.redirect "#{redirect}?token=#{token}"
      # remove session created during authentication
      req.session.destroy()
    ) req, res, next

# Authorization (disabled for tests):
# Once authenticated, a user has been returned a authorization token.
# this token is used to allow to connect with socket.io. 
# For administraction namespaces, the user rights are to be checked also.

io.configure -> io.set 'authorization', (handshakeData, callback) ->
  # allways allo access without security
  return callback null, true if noSecurity
  # check if a token has been sent
  token = handshakeData.query.token
  return callback 'No token provided' if 'string' isnt utils.type(token) or token.length is 0

  # then identifies player with this token
  playerService.getByToken token, (err, player) ->
    return callback err if err?
    # if player exists, authorization awarded !
    if player?
      logger.info "Player #{player.email} connected with token #{token}"
      # this will allow to store connected player into the socket details
      handshakeData.playerEmail = player.email
    callback null, player?

# When a client connects, returns it immediately its token
io.on 'connection', (socket) ->
  email = socket.manager.handshaken[socket.id]?.playerEmail
  # always use admin without security
  email = 'admin' if noSecurity

  # set inactivity
  playerService.activity email

  # retrieve the player email set during autorization phase, and stores it.
  socket.set 'email', email

  # on each connection, generate a key for dev access
  key = null

  # set socket id to player
  playerService.getByEmail email, false, (err, player) ->
    return logger.warn "Failed to retrieve player #{email} to set its socket id: #{err or 'no player found'}" if err? or player is null
    player.socketId = socket.id
    if player.isAdmin
      key = utils.generateToken 24
      notifier.notify 'admin-connect', email, key
    player.save (err) ->
      return logger.warn "Failed to set socket id of player #{email}: #{err}" if err?

  # message to get connected player
  socket.on 'getConnected', (callback) ->
    socket.get 'email', (err, value) ->
      return callback err if err?
      playerService.getByEmail value, false, (err, player) =>
        # return key to rheia
        player.key = key if key? and player?
        callback err, player

  # message to manually logout the connected player
  socket.on 'logout', ->
    socket.get 'email', (err, value) ->
      playerService.disconnect value, 'logout'

# socket.io `game` namespace 
#
# 'game' namespace exposes all method of GameService, plus a special 'currentPlayer' method.
# @see {GameService}
io.of('/game').on 'connection', (socket) ->
  exposeMethods gameService, socket, ['resolveRules', 'executeRule']

# socket.io `admin` namespace 
#
# configure the differents message allowed
# 'admin' namespace is associated to AdminService, ImageService, AuthoringService, 
# DeployementService and SearchService
#
# send also notification of the Notifier
# @see {AdminService}
adminNS = io.of('/admin').authorization(checkAdmin).on 'connection', (socket) ->    
  exposeMethods adminService, socket, ['save', 'remove']
  exposeMethods imagesService, socket
  exposeMethods searchService, socket
  exposeMethods authoringService, socket, ['move'], ['readRoot', 'save', 'remove']
  exposeMethods deployementService, socket, ['deploy', 'commit', 'rollback', 'createVersion']
  exposeMethods ruleService, socket, [], ['export', 'resolve', 'execute']

  # do not expose all playerService methods, but just disconnection with the 'kick' message
  socket.on 'kick', (email) ->
    playerService.disconnect email, 'kicked', ->

  # add a message to returns connected list
  socket.on 'connectedList', (reqId) ->
    socket.emit 'connectedList-resp', reqId, playerService.connectedList

# socket.io `updates` namespace 
#
# 'updates' namespace will broadcast all modifications on the database.
# The event name will be 'creation', 'update' or 'deletion', and as parameter,
# the concerned instance (only the modified parts for an update)
#
# @see {ModelWatcher.change}
updateNS = io.of('/updates')

watcher.on 'change', (operation, className, instance) ->
  logger.debug "broadcast of #{operation} on #{instance.id} (#{className})"
  updateNS.emit operation, className, instance

notifier.on notifier.NOTIFICATION, (scope, event, details...) ->
  if event is 'disconnect'
    # close socket of disconnected user.
    socket =  io?.sockets?.sockets?[details[0].socketId]
    return unless socket?  
    socket.disconnect()
    logger.info "disconnect user #{details[0].email} for #{details[1]}"
  if scope is 'time' 
    updateNS?.emit 'change', 'time', details[0] 
  else
    adminNS?.emit.apply adminNS, [scope, event].concat details

# send all log within admin namespace
LoggerFactory.on 'log', (details) ->
  try
    adminNS?.emit 'log', details
  catch err
    # avoid crashing server if a log message cannot be sent
    process.stderr.write "failed to send log to client: #{err}"

# Authentication: 
# Configure a passport strategy to use Google and Twitter Oauth2 mechanism.
# Configure also a strategy for manually created accounts.
# Browser will be redirected to success Url with a `token` parameter in case of success 
# Browser will be redirected to success Url with a `err` parameter in case of failure
passport.use new LocalStrategy playerService.authenticate
registerOAuthProvider 'google', GoogleStrategy, playerService.authenticatedFromGoogle, ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email']
registerOAuthProvider 'twitter', TwitterStrategy, playerService.authenticatedFromTwitter

# `POST /auth/login`
#
# The authentication API for manually created accounts. 
# It needs `username` and `password` form parameters
# Once authenticated, browser is redirected with autorization token in url parameter
app.post '/auth/login', (req, res, next) ->
  passport.authenticate('local', (err, token, details) ->
    # authentication failed
    err = details.message if token is false
    # depending on the requested result, redirect or send redirection in json
    res.format
      html: ->
        res.redirect "#{getRedirect req}?#{if err? then "error=#{err}" else "token=#{token}"}"
      
      json: ->
        result = redirect: getRedirect req
        if err?
          result.error = err
        else
          result.token = token
        res.json result
    
  ) req, res, next

# `GET /konami`
#
# Just a fun test page to ensure the server is running.
# Responds the conami code in a `<pre>` HTML markup
app.get '/konami', (req, res) ->
  res.send '<pre>↑ ↑ ↓ ↓ ← → ← → B A</pre>'
  
# Exports the application.
module.exports = 
  server: server
  app: app