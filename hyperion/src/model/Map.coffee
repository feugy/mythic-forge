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

typeFactory = require './typeFactory'
conn = require './connection'
logger = require('../logger').getLogger 'model'

# Define the schema for map item types
Map = typeFactory 'Map', 
    # kind of map: square, diamond, hexagon
    kind: 
        type: String
        default: 'hexagon'
  , {strict:true, noDesc: true}


# pre-save middleware: once map is removed, removes also fields and items on it
#
# @param next [Function] function that must be called to proceed with other middleware.
Map.pre 'remove', (next) ->
  # performs removal
  next()
  # now removes fields and items on it
  # does not issue messages
  # does not load models
  require('./Field').remove(mapId:@_id).exec()
  require('./Item').remove(map:@_id).exec()

module.exports = conn.model 'map', Map