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
'use strict'

logger = require('../logger').getLogger 'web'
express = require 'express'
path = require 'path'
fs = require 'fs'
coffee = require 'coffee-script'
utils = require '../utils'

# creates a single server to serve static files
app = express.createServer()

publicFolder = utils.confKey 'server.staticFolder'

# js, images and style files will be statically served...
staticPaths = ['js', 'assets', 'style']
app.use "/#{staticPath}", express.static path.join publicFolder, staticPath for staticPath in staticPaths

# on-the-fly express compilation. Must be after static configuration to avoid compiling js external libraries
app.get /^(.*)\.js$/, (req, res, next) ->
  # read the coffe corresponding file
  file = path.join publicFolder, req.params[0]+'.coffee'
  fs.readFile file, (err, content) => 
    return res.send err, 404 if err?
    # try to compile it
    try 
      res.header 'Content-Type', 'application/javascript'
      res.send coffee.compile content.toString()
    catch exc
      console.error "Failed to compile #{file}: #{exc}"
      res.send exc, 500

## ...but SPA root need to be treaten differently, because of pushState
app.get '*', (req, res, next) ->
  for staticPath in staticPaths
    if req.url.indexOf("/#{staticPath}") is 0
      return next()
  fs.createReadStream(path.join(publicFolder, 'index.html')).pipe res

# Exports the application.
module.exports = app
