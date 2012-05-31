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
