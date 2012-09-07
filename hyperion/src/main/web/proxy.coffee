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
coffee = require 'coffee-script'
utils = require '../utils'
stylus = require 'stylus'

# creates a single server to serve static files
app = express()

# Configure the proxy to serve a Rich Internet application on a given context
#
# @param base [String] base part of the RIA url. Files will be served under this url. Must not end with '/'
# Must not be a subpart of another RIA
# @param rootFolder [String] path to the local folder that contains the RIA files.
# @param statics [Array<String>] Array of path relative to `rootFolder` that will be statically served
# @param compiledPath [String] A path under which js files will be the compilation result of coffee files
configureRIA = (base, rootFolder, statics) ->
  # serve static files
  app.use "#{base}/#{stat}", express.static path.join rootFolder, stat for stat in statics

  # Specific configuration file.
  app.get "#{base}/conf.js", (req, res, next) ->
    staticPort = utils.confKey 'server.staticPort'
    host = utils.confKey 'server.host'
    baseUrl = "http://#{host}"
    # port 80 must be omitted, to allow images resolution on client side.
    if staticPort isnt 80
      baseUrl += ":#{staticPort}"
    # compute the client configuration
    conf = 
      separator: path.sep
      basePath: "#{base}/"
      baseUrl: "#{baseUrl}#{base}"
      apiBaseUrl: "https://#{host}:#{utils.confKey 'server.apiPort'}"
      imagesUrl: "#{baseUrl}/images/"

    res.header 'Content-Type', 'application/javascript; charset=UTF-8'
    res.send "window.conf = #{JSON.stringify conf}"

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
        return res.send err, 500 if err?
        res.header 'Content-Type', 'text/css'
        res.send css
         
  # SPA root need to be treaten differently, because of pushState. Must be after compilation middleware.
  app.get "#{base}*", (req, res, next) ->
    # let the static middleware serve static resources !
    for stat in statics
      if 0 is req.url.indexOf "#{base}/#{stat}"
        return next();
    pathname = url.parse(req.url).pathname.slice base.length+1
    # necessary to allow resolution of relative path on client side. Urls must ends with /
    pathname = if pathname.indexOf('.html') is -1 then 'index.html' else pathname
    res.header 'Content-Type', 'text/html; charset=UTF-8'
    fs.createReadStream(path.join(rootFolder, pathname || 'index.html')).on('error', () =>
      res.send 404
    ).pipe res


# serve commun static assets
app.use "/images", express.static utils.confKey 'images.store'

# configure a game RIA and the administration RIA 
configureRIA '/game', utils.confKey('server.gameFolder'), ['js', 'assets', 'style']
configureRIA '/rheia', './rheia/src', ['js', 'style']

# Exports the application.
module.exports = app
