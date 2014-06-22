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
Item = require './Item'
conn = require './connection'
modelUtils = require '../util/model'

# Define the schema for map event with properties
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
  instanceProperties: true
  typeClass: 'EventType'
  strict: false
  middlewares:

    # pre-init middleware: retrieve the Item corresponding to the stored from id.
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    # @param event [Item] the initialized event.
    init: (next, event) ->
      return next() unless event.from?
      # loads the type, but not from local cache to be able to modify it without side effects
      Item.findById event.from, (err, item) ->
        return next(new Error "Unable to init event #{event.id}. Error while resolving its from: #{err}") if err?
        # Do the replacement
        event.from = item
        # Never use resolved item, or it may lead to circular references. 
        # Use unresolved linked properties instead, not marking it as modified 
        modelUtils.processLinks event.from, event?.type?.properties, false if event.from?
        next()

    # pre-save middleware: only save the from reference, not the whole object
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    save: (next) ->
      # check that creation date has not been modified, and update update date.
      return next new Error 'creation date cannot be modified for an Event' if @isModified 'created'
      @updated = new Date()

      # replace from with its id, for storing in Mongo, without using setters.
      saveFrom = @from
      @_doc.from = saveFrom?.id
      next()
      # restore save to allow reference reuse.
      @_doc.from = saveFrom

module.exports = conn.model 'event', Event