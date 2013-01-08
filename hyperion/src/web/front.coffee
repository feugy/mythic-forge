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
path = require 'path'
url = require 'url'
fs = require 'fs'
http = require 'http'
coffee = require 'coffee-script'
utils = require '../util/common'
stylus = require 'stylus'
notifier = require('../service/Notifier').get()

# Stores authorized tokens to avoid requesting to much playerService
authorizedTokens = {}
# Register handler on players connection and disconnection
notifier.on notifier.NOTIFICATION, (event, state, player) ->
  return unless event is 'players'
  if state is 'connect'
    if player.isAdmin
      logger.debug "allow static connection from player #{player.id}"
      # adds an entry to grant access on secured RIA 
      token = player.token
      authorizedTokens[token] = player.id 
  else if state is 'disconnect'
    logger.debug "deny static connection from player #{player.id}"
    # removes entry from the cache
    for token, id of authorizedTokens when id is player.id
      delete authorizedTokens[token]
      break

# exports a function to reuse existing express application
#
# @param app [Object] existing express server. Default to null
# @return the configures express server, which needs to be started
module.exports = (app = null) ->

  unless app?
    # creates a single server to serve static files
    app = express()

  # Register a specific route to return configuration file
  # 
  # @param base [String] base part of the RIA url. Files will be served under this url. Must not end with '/'
  registerConf = (base) ->
    app.get "#{base}/conf.js", (req, res, next) ->
      port = utils.confKey 'server.bindingPort', utils.confKey 'server.staticPort'
      host = utils.confKey 'server.host'
      baseUrl = "http://#{host}"
      # port 80 must be omitted, to allow images resolution on client side.
      if port isnt 80
        baseUrl += ":#{port}"
      # compute the client configuration
      conf = 
        separator: path.sep
        basePath: "#{base}/"
        baseUrl: "#{baseUrl}#{base}"
        apiBaseUrl: "#{if certPath = utils.confKey('ssl.certificate', null)? then 'https' else 'http'}://#{host}:#{utils.confKey 'server.apiPort'}"
        imagesUrl: "#{baseUrl}/images/"

      res.header 'Content-Type', 'application/javascript; charset=UTF-8'
      res.send "window.conf = #{JSON.stringify conf}"


  # Configure the proxy to serve a Rich Internet application on a given context
  #
  # @param base [String] base part of the RIA url. Files will be served under this url. Must not end with '/'
  # Must not be a subpart of another RIA
  # @param rootFolder [String] path to the local folder that contains the RIA files.
  # @param isStatic [Boolean] No coffee or stylus compilation provided. Default to false.
  # @param securedRedirect [String] Access to this RIA is secured and need authentication. This base string is used to
  # redirect incoming request that are not authentified or allowed. Default to null.
  # @param
  configureRIA = (base, rootFolder, isStatic = false, securedRedirect = null) ->

    if securedRedirect?
      # if RIA is secured, register first a security filter
      app.get new RegExp("^#{base}"), (req, res, next) ->
        token = req.signedCookies?.token
        # redirect unless cookie exists
        return res.redirect "#{securedRedirect}?redirect=#{encodeURIComponent req.url}" unless token?
        # proceed if cookie value is known
        return next() if token of authorizedTokens
        # removes the cookie and deny
        res.clearCookie 'token'
        res.redirect "#{securedRedirect}?error=#{encodeURIComponent "#{base} not authorized"}"

    registerConf base

    unless isStatic
      # on-the-fly coffee-script compilation. Must be after static configuration to avoid compiling js external libraries
      app.get new RegExp("^#{base}/(.*)\.js$") , (req, res, next) ->
        # read the coffe corresponding file
        file = path.join rootFolder, "#{req.params[0]}.coffee"
        fs.readFile file, (err, content) => 
          # file not found.
          if err?
            return next if 'ENOENT' is err.code then null else err
          # try to compile it
          try 
            res.header 'Content-Type', 'application/javascript'
            res.send coffee.compile content.toString()
          catch exc
            logger.error "Failed to compile #{file}: #{exc}"
            res.send exc, 500

      # on-the-fly stylus compilation. Must be after static configuration to avoid compiling js external libraries
      app.get new RegExp("^#{base}/(.*)\.css$") , (req, res, next) ->
        # read the stylus corresponding file
        file = path.join rootFolder, "#{req.params[0]}.styl"
        parent = path.dirname file
        fs.readFile file, (err, content) => 
          # file not found.
          if err?
            return next if 'ENOENT' is err.code then null else err 
          # try to compile it
          stylus(content.toString(), {compress:true}).set('paths', [parent]).render (err, css) ->
            if err?
              logger.error "Failed to compile #{file}: #{err}"
              return res.send err, 500
            res.header 'Content-Type', 'text/css'
            res.send css
           
    # SPA root need to be treaten differently, because of pushState. Must be after compilation middleware.
    app.get new RegExp("^#{base}(/\\w*)*(?!\\.\\w+)$"), (req, res, next) ->
      # redirects with trailing slash to avoid relative path errors from browser
      return res.redirect "#{base}/" if req.url is "#{base}"

      pathname = url.parse(req.url).pathname.slice(base.length+1) or 'index.html'
      # If file exists, serve it statically
      fs.exists path.join(rootFolder, pathname), (exists) =>
        return next() if exists
        # not found: send root file or 404
        fs.createReadStream(path.join(rootFolder, 'index.html')).on('error', => res.send 404).pipe res
        res.header 'Content-Type', 'text/html; charset=UTF-8'

    # last resort: serve static files: cache for 3 weeks if static
    app.use "#{base}", express.static rootFolder, maxAge: if isStatic then 1814400000 else 0

  # serve commun static assets
  app.use express.cookieParser utils.confKey 'server.cookieSecret'
  app.use '/images', express.static utils.confKey('images.store'), maxAge: 1814400000
  # serve static pages from the docs folder
  app.use express.static 'docs'
  app.use express.compress level:9
  
  # configure a game RIA and the administration RIA 
  configureRIA '/game', utils.confKey('game.production'), true
  configureRIA '/dev', utils.confKey('game.dev'), false, '/rheia/login'

  if process.env.NODE_ENV in ['buyvm', 'simons']
    configureRIA '/rheia', './rheia-min', true
  else
    configureRIA '/rheia', './rheia'

  app