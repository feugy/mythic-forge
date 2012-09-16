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
Map = require './Map'

# Define the schema for map event: no name or desc, and properties
Item = typeFactory 'Item', 
  # link to map
  map: {}
  x: 
    type: Number
    default: null
  y: 
    type: Number
    default: null
  # image number in the images array of the corresponding item type.
  imageNum: 
    type: Number
    default: 0
  # states give tips to clients for rendering the Item. They allow for exemple to display
  # som lone-live animation. For example, 'sleep' state while display a snoring animation.
  state: 
    type: String
    default: null
  # transition are special actions that lives during the update of the item rendering.
  # for exemple, it reflects the move animation while updating the map position
  # client will reset it to null after the rendering was updated.
  transition: 
    type: String
    default: null
    set: (value) ->
      # force transition to appear in modifiedPath, to allow propagation
      @markModified('transition')
      value
, 
  noCache: true
  noDesc: true
  noName: true
  instanceProperties: true
  typeClass: 'ItemType'
  strict: false
        
# pre-init middleware: retrieve the map corresponding to the stored id.
#
# @param item [Item] the initialized item.
# @param next [Function] function that must be called to proceed with other middleware.
Item.pre 'init', (next, item) ->
  return next() unless item.map?
  # loads the type from local cache
  Map.findCached item.map, (err, map) ->
    return next(new Error "Unable to init item #{item._id}. Error while resolving its map: #{err}") if err?
    return next(new Error "Unable to init item #{item._id} because there is no map with id #{item.map}") unless map?    
    # Do the replacement.
    item.map = map
    next()

# pre-save middleware: only save the map reference, not the whole object
#
# @param next [Function] function that must be called to proceed with other middleware.
Item.pre 'save', (next) ->
  # replace map with its id, for storing in Mongo, without using setters.
  saveMap = @map
  @_doc.map = saveMap?._id
  next()
  # restore save to allow reference reuse.
  @_doc.map = saveMap

# Export the Class.
module.exports = conn.model 'item', Item
