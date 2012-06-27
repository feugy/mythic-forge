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

define [
  'backbone'
  'jquery'
  'i18n!nls/edition'
  'utils/utilities'
  'model/ItemType'
], (Backbone, $, editionLabels, utilities, ItemType) ->

  editionLabels = _.extend {}, editionLabels

  # Displays and edit an ItemType on edition perspective
  class ItemTypeView extends Backbone.View

    # the edited object
    edited: null

    # **private**
    # while the edited object is still not saved on server, we need an id.
    _tempId: null

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (@router, id) ->
      super {tagName: 'div', className:'itemType'}
      # creation of a new item type if necessary
      if id?
        @edited = ItemType.collection.get id
      else 
        @edited = new ItemType()
        @_tempId = utilities.generateId()
      console.log "creates item type edition view for #{if id? then @edited.id else 'a new object'}"

    # Returns a unique id. 
    #
    # @return If the edited object is persisted on server, return its id. Otherwise, a temporary unic id.
    getId: =>
      (if @_tempId isnt null then @_tempId else @edited.id)

    # Returns the view's title
    #
    # @return the edited object name.
    getTitle: =>
      @edited.get 'name'

    # Method invoked when the view must be closed.
    # @return true if the view can be closed, false to cancel closure
    canClose: =>
      true

    # The `render()` method is invoked by backbone to display view content at screen.
    render: =>
      @$el.append "coucou #{@edited.get 'name'}"

      # for chaining purposes
      return @

  return ItemTypeView