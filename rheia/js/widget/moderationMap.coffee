###
  Copyright 2010,2011,2012 Damien Feugas
  
  This file is part of Mythic-Forge.

  Myth is free software: you can redistribute it and/or modify
  it under the terms of the GNU Lesser Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  at your option any later version.

  Myth is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU Lesser Public License for more details.

  You should have received a copy of the GNU Lesser Public License
  along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

define [
  'jquery'
  'underscore'
  'widget/authoringMap'
  'widget/mapItem'
],  ($, _) ->

  # Specific map that adds items support to authoring Map, and remove selection features
  # triggers an `itemClicked` event with model as attribute when clicked
  $.widget 'rheia.moderationMap', $.rheia.authoringMap,
    
    options:   

      # map id, to ignore items and fields that do not belongs to the displayed map
      mapId: null

    # **private**
    # disable selection for this widget
    _selectable: false

    # **private**
    # layer that holds items
    _itemLayer: null

    # **private**
    # stores items rendering, organized by item id, for faster access
    _itemWidgets: {}

    # **private**
    # Number of pending loading items 
    _loading: 0

    # Adds field or items to map. Will be effective only if the objects is inside displayed bounds.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param added [Array<Object>] added data (JSON array). 
    addData: (added) ->
      o = @options

      # end of item loading: removes old items and reset layer position
      checkLoadingEnd = =>
        return unless @_loading is 0
        # removes previous widgets
        for id, widget of @_oldWidgets
          widget.destroy()
          widget.element.remove()
        @_oldWidgets = {}
        # all widget are loaded: reset position
        @_itemLayer.css 
          top:0
          left: 0

      # separate fields from items
      fields = []
      for obj in added
        if obj.constructor.name is 'Field'
          fields.push obj.toJSON() if o.mapId is obj.get 'mapId'
        else if obj.constructor.name is 'Object'
          # zoom case: reinject existing fields
          fields.push obj
        else if obj.constructor.name is 'Item' and o.mapId is obj.get('map')?.id
          @_loading++
          _.defer =>
            # creates widget for this item
            @_itemWidgets[obj.id] = $('<span></span>').mapItem(
              model: obj
              map: @
              clicked: (event, item) =>
                @_trigger 'itemClicked', event, item
              loaded: =>
                @_loading--
                checkLoadingEnd()
            ).data 'mapItem'
            # and adds it to item layer
            @_itemLayer.append @_itemWidgets[obj.id].element

      checkLoadingEnd()
      
      # let superclass manage fields
      $.rheia.authoringMap::addData.call @, fields if fields.length > 0

    # Removes field or itemsfrom map. Will be effective only if the field was displayed.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param removed [Field] removed data (JSON array). 
    removeData: (removed) ->
      # TODO
      # let superclass manage fields
      $.rheia.authoringMap::removeData.call @, removed

    # **private**
    # Build rendering
    _create: ->
      # superclass call
      $.rheia.authoringMap::_create.apply @, arguments

      # adds the item layer.    
      @_itemLayer = $("<div class='items movable' style='height:#{@_height*3}px; width:#{@_width*3}px '></div>").appendTo @_container

    # **private**
    # Method invoked when the widget options are set. Update rendering if `current` or `images` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      # superclass inherited behaviour
      $.rheia.authoringMap::_setOption.apply @, arguments
      switch key
        when 'lowerCoord'
          @_oldWidgets = _.clone @_itemWidgets