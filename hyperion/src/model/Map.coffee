###
  Copyright 2010~2014 Damien Feugas
  
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
logger = require('../util/logger').getLogger 'model'
modelWatcher = require('./ModelWatcher').get()
modelUtils = require '../util/model'

# Define the schema for map item types
Map = typeFactory 'Map', module,
  # kind of map: square, diamond, hexagon
  kind: 
    type: String
    default: 'hexagon'

  # dimension of a tile in this map
  tileDim:
    type: Number
    default: 100
, 
  strict:true
  middlewares:
    # once map is removed, removes also fields and items on it
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    remove: (next) ->
      # now removes fields and items on it without loading models
      require('./Field').where('mapId', @id).remove (err) =>
        return logger.error "Faild to remove fields of deleted map #{@id}: #{err}" if err?
      require('./Item').where('map', @id).select(_id:1).lean().exec (err, objs) =>
        return logger.error "Faild to select items of deleted map #{@id}: #{err}" if err?
        require('./Item').where('map', @id).remove (err) =>
          return logger.error "Faild to remove items of deleted map #{@id}: #{err}" if err?
          # issue events for caches and clients
          modelWatcher.change 'deletion', 'Item', obj for obj in objs
          # performs removal
          next()

module.exports = conn.model 'map', Map