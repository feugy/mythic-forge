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
Map = require './Map'

# Define the schema for map item with its properties
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
  # some long-live animation. For example, 'sleep' state while display a snoring animation.
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
      if value isnt @_doc.transition
        # force transition to appear in modifiedPath, to allow propagation
        @markModified 'transition'
      value

  # For quantifiable items, available quantity
  quantity:
    type: Number
    default: null
, 
  instanceProperties: true
  typeClass: 'ItemType'
  strict: false
  middlewares:
    
    # pre-init middleware: retrieve the map corresponding to the stored id.
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    # @param item [Item] the initialized item.
    init: (next, item) ->
      return next() unless item.map?
      # loads the type from local cache
      Map.findCached [item.map], (err, maps) ->
        return next(new Error "Unable to init item #{item.id}. Error while resolving its map: #{err}") if err?
        return next(new Error "Unable to init item #{item.id} because there is no map with id #{item.map}") unless maps.length is 1    
        # Do the replacement.
        item.map = maps[0]
        next()

    # pre-save middleware: only save the map reference, not the whole object
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    save: (next) ->
      # enforce quantity value regarding the type quantifiable attribute
      if @type?.get 'quantifiable'
        @set 'quantity', 0 unless @get('quantity')?
      else
        @set 'quantity', null if @get('quantity')?

      # replace map with its id, for storing in Mongo, without using setters.
      saveMap = @map
      @_doc.map = saveMap?.id
      next()
      # restore save to allow reference reuse.
      @_doc.map = saveMap

# Export the Class.
module.exports = conn.model 'item', Item