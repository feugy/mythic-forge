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

# creates a single server to serve static files
app = express.createServer()

# on-the-fly express compilation and static file configuration
publicFolder = path.join __dirname, '../../../src/client'
app.use express.compiler
    src: publicFolder,
    dest: publicFolder,
    enable: ['coffeescript']

# js, images and style files will be statically served...
app.use '/js', express.static path.join publicFolder, 'js'
app.use '/assets', express.static path.join publicFolder, 'assets'
app.use '/style', express.static path.join publicFolder, 'style'

## ...but SPA root need to be treaten differently, because of pushState
app.get '*', (req, res, next) ->
  if req.url.indexOf('/js') is 0 or req.url.indexOf('/assets') is 0 or req.url.indexOf('/style') is 0
    return next()
  fs.createReadStream(path.join(publicFolder, 'index.html')).pipe res

# Exports the application.
module.exports = app
