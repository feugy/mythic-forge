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
Item = require './Item'
conn = require './connection'

# Define the schema for map event: no name or desc, and properties
Event = typeFactory 'Event', 

  # creation date. May not be modified
  created:
    type: Date
    default: -> new Date()

  # last modification date. Automatically modified when saving
  updated:
    type: Date
    default: -> new Date()

  # Item that originate the event. 
  from: 
    type: {}
    default: -> null # use a function to force instance variable
, 
  noDesc: true
  noName: true
  instanceProperties: true
  typeClass: 'EventType'
  strict: false
  middlewares:

    # pre-init middleware: retrieve the Item corresponding to the stored from id.
    #
    # @param item [Item] the initialized item.
    # @param next [Function] function that must be called to proceed with other middleware.
    init: (next, event) ->
      return next() unless event.from?
      # loads the type from local cache
      Item.findCached [event.from], (err, items) ->
        return next(new Error "Unable to init event #{event._id}. Error while resolving its from: #{err}") if err?
        return next(new Error "Unable to init event #{event._id} because there is no from with id #{event.from}") unless items.length is 1    
        # Do the replacement.
        event.from = items[0]
        next()

    # pre-save middleware: only save the from reference, not the whole object
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    save: (next) ->
      # check that creation date has not been modified, and update update date.
      return next new Error 'creation date cannot be modified for an Event' if @isModified 'created'
      @set 'updated', new Date()

      # replace from with its id, for storing in Mongo, without using setters.
      saveFrom = @from
      @_doc.from = saveFrom?._id
      next()
      # restore save to allow reference reuse.
      @_doc.from = saveFrom

module.exports = conn.model 'event', Event
