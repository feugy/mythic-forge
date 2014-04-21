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
SocketServer = require 'socket.io'
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
apiPort = utils.confKey 'server.apiPort', process.env.PORT or ''

# Transforms models into plain JSON, using their toJSON() method
# Goes deeper into arrays and objects to find models
# Do NOT send circular trees !
#
# @param args [Object|Array] models to transform to plain JSON
# @return the corresponding plain JSON
plainObjects = (args) ->
  isArray = 'array' is utils.type args
  unless isArray
    args = [args] 
  for arg, i in args 
    if 'array' is utils.type arg
      args[i] = plainObjects arg
    if 'object' is utils.type(arg) 
      if 'function' is utils.type arg.toJSON
        args[i] = arg.toJSON()
      else
        arg[attr] = plainObjects([val])[0] for attr, val of arg
  if isArray then args else args[0]

# stores email corresponding to socket ids
sid = {}

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
io = new SocketServer().listen server

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
  email = if noSecurity then 'admin' else sid[socket.id].email

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
            logger.debug "returning #{method} #{reqId} response #{if arguments[0]? then arguments[0] else ''}"
            # returns the callback arguments
            returnArgs = Array.prototype.slice.call arguments
            # first response parameters are always method name and request id
            returnArgs.splice 0, 0, "#{method}-resp", reqId
            # expand errors
            returnArgs[2] = returnArgs[2].message if utils.isA returnArgs?[2], Error
            socket.emit.apply socket, plainObjects returnArgs

          # invoke the service layer with arguments 
          logger.debug "processing #{method} #{reqId} message with arguments #{originalArgs}"
          service[method].apply service, args

# Authorization method for namespaces.
# Get the connected player email from handshake data and allow only if player has administration right
#
# @param socket [Object] the socket involved
# @param callback [Function] authorization callback, invoked parameter
# @option callback err [String] an error message, or null if no error occured
checkAdmin = (socket, callback) ->
  # always give access for tests
  return callback null if noSecurity
  # check connected user rights
  details = sid[socket.id]
  callback if details?.isAdmin then null else new Error 'unauthorized'
    
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
      callbackURL: "#{if certPath? then 'https' else 'http'}://#{host}:#{bindingPort or apiPort}/auth/#{provider}/callback"
    , verify

    args = session: false, scope: scopes

  else
    # OAuth provider
    passport.use new strategy
      consumerKey: utils.confKey "authentication.#{provider}.id"
      consumerSecret: utils.confKey "authentication.#{provider}.secret"
      callbackURL: "#{if certPath? then 'https' else 'http'}://#{host}:#{bindingPort or server.apiPort}/auth/#{provider}/callback"
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
io.use (socket, callback) ->
  # allways allo access without security
  return callback null if noSecurity
  # check if a token has been sent
  token = socket.request.query?.token
  if 'string' isnt utils.type(token) or token.length is 0
    logger.debug "socket #{socket.id} received invalid token #{token}"
    return callback new Error 'invalidToken' 

  # then identifies player with this token
  playerService.getByToken token, (err, player) ->
    return callback new Error err if err?
    # if player exists, authorization awarded !
    if player?
      logger.info "Player #{player.email} connected with token #{token}"
      # this will allow to store connected player into the socket details
      sid[socket.id] = 
        email: player.email
        isAdmin: player.isAdmin
      return callback null
    logger.debug "socket #{socket.id} received unknown token #{token}" 
    return callback new Error 'invalidToken'

# When a client connects, returns it immediately its token
io.on 'connection', (socket) ->
  # always use admin without security
  details = unless noSecurity then sid[socket.id] else email:'admin', isAdmin:true
  # set inactivity
  playerService.activity details.email
  logger.debug "socket #{socket.id} established for user #{details.email}" 

  # on each connection, generate a key for dev access
  if details.isAdmin
    key = utils.generateToken 24
    notifier.notify 'admin-connect', details.email, key
  else
    key = null

  # message to get connected player
  socket.on 'getConnected', (callback) ->
    playerService.getByEmail details.email, false, (err, player) =>
      # return key to rheia
      player.key = key if key? and player?
      callback err, player
    socket.removeAllListeners()

  # message to manually logout the connected player
  socket.on 'logout', ->
    logger.debug "received logout for user #{details.email}" 
    # manually disconnect and clear the sid (disconnect event isn't fired)
    socket.disconnect true
    delete sid[socket.id]
    playerService.disconnect details.email, 'logout'

  # don't forget to clean up connected socket email
  socket.on 'disconnect', ->
    logger.debug "socket #{socket.id} closed user #{details.email}" 
    delete sid[socket.id]

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
adminNS = io.of('/admin').use(checkAdmin).on 'connection', (socket) ->  
  exposeMethods adminService, socket, ['save', 'remove']
  exposeMethods imagesService, socket
  exposeMethods searchService, socket
  exposeMethods authoringService, socket, ['move'], ['readRoot', 'save', 'remove']
  exposeMethods deployementService, socket, ['deploy', 'commit', 'rollback', 'createVersion']
  exposeMethods ruleService, socket, [], ['export', 'resolve', 'execute']

  # do not expose all playerService methods, but just disconnection with the 'kick' message
  socket.on 'kick', (reqId, email) ->
    playerService.disconnect email, 'kicked', ->
      logger.info "kick user #{email}" 
      # close socket of disconnected user.
      for id, val of sid when val.email is email
        # manually disconnect and clear the sid (disconnect event isn't fired)
        delete sid[id]
        _.findWhere(io.sockets.sockets, id: id)?.disconnect true
        break

  # add a message to returns connected list
  socket.on 'connectedList', (reqId) ->
    socket.emit 'connectedList-resp', reqId, plainObjects playerService.connectedList

# socket.io `updates` namespace 
#
# 'updates' namespace will broadcast all modifications on the database.
# The event name will be 'creation', 'update' or 'deletion', and as parameter,
# the concerned instance (only the modified parts for an update)
#
# @see {ModelWatcher.change}
updateNS = io.of('/updates')

watcher.on 'change', (operation, className, changes) ->
  logger.debug "broadcast of #{operation} on #{changes.id} (#{className})"
  updateNS.emit operation, className, plainObjects changes
  # also update sid if isAdmin status is modified
  if className is 'Player' 
    if operation is 'update' and changes.isAdmin?
      for details of sid when details.email is changes.email
        details.isAdmin = changes.isAdmin
        break
    if operation is 'deletion'
      for details, id of sid when details.email is changes.email
        delete sid[id]
        onNotification notifier.NOTIFICATION, 'disconnect', [changes, 'deletion']
        break

notifier.on notifier.NOTIFICATION, (scope, event, details...) ->
  if scope is 'time' 
    updateNS?.emit 'change', 'time', plainObjects details[0] 
  else
    adminNS?.emit?.apply adminNS, plainObjects [scope, event].concat details

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
passport.use new LocalStrategy playerService.authenticate, 
registerOAuthProvider 'google', GoogleStrategy, playerService.authenticatedFromGoogle, ['https://www.googleapis.com/auth/userinfo.profile', 'https://www.googleapis.com/auth/userinfo.email']
registerOAuthProvider 'twitter', TwitterStrategy, playerService.authenticatedFromTwitter

# `POST /auth/login`
#
# The authentication API for manually created accounts. 
# It needs `username` and `password` form parameters
# Once authenticated, browser is redirected with autorization token in url parameter
app.post '/auth/login', (req, res, next) ->
  passport.authenticate('local', {badRequestMessage: "missingCredentials"}, (err, token, details) ->
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