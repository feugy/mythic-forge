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
  'utils/utilities'
  'widget/authoringMap'
  'widget/mapItem'
],  ($, _, utils) ->

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

    # **private**
    # Dragged item candidates
    _dragged: []

    # **private**
    # Flag to indicate wether the dragged item is inside or outside the widget
    _draggedInside: false

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
        widget.destroy() for id, widget of @_oldWidgets
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
          @_itemWidgets[obj.id] = true
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
              destroy: (event, widget) =>
                # when reloading, it's possible that widget have already be replaced
                return unless @_itemWidgets[obj.id] is widget
                delete @_itemWidgets[obj.id]
            ).data 'mapItem'
            # and adds it to item layer
            @_itemLayer.append @_itemWidgets[obj.id].element

      checkLoadingEnd()
      
      # let superclass manage fields
      $.rheia.authoringMap::addData.call @, fields if fields.length > 0

    # Checks if the corresponding item is displayed or not
    # 
    # @param item [Object] checked item
    # @return true if the map contains a mapItem widget that displays this item
    hasItem: (item) ->
      @_itemWidgets[item?.id]?

    # Removes field or itemsfrom map. Will be effective only if the field was displayed.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param removed [Field] removed data (JSON array). 
    removeData: (removed) ->
      # separate fields from items
      fields = []
      for obj in removed
        if obj.constructor.name is 'Field'
          fields.push obj.toJSON() if @options.mapId is obj.get 'mapId'
        else if obj.constructor.name is 'Item'
          # immediately removes corresponding widget
          @_itemWidgets[obj.id]?.destroy()

      # let superclass manage fields
      $.rheia.authoringMap::removeData.call @, fields if fields.length > 0

    # **private**
    # Build rendering
    _create: ->
      # superclass call
      $.rheia.authoringMap::_create.apply @, arguments

      # adds the item layer.    
      @_itemLayer = $("<div class='items movable' style='height:#{@_height*3}px; width:#{@_width*3}px'></div>").appendTo @_container

    # **private**
    # Method invoked when the widget options are set. Update rendering if `current` or `images` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      switch key
        when 'lowerCoord'
          @_oldWidgets = _.clone @_itemWidgets
        when 'mapId'
          if @options.mapId isnt value
            # reset all rendering: fields and items.
            canvas = @element.find('.fields')[0]
            canvas.width = canvas.width
            widget.destroy() for id, widget of @_itemWidgets
            @_itemWidgets = {}

      # superclass inherited behaviour
      $.rheia.authoringMap::_setOption.apply @, arguments

    # **private**
    # Drag'n drop start handler. Allow to drag items if item selected.
    #
    # @param event [Event] drag'n drop start mouse event
    # @return false to cancel the jQuery drag'n drop operation
    _onDragStart: (event) ->
      #  cancels drag if we have multiple dragged target
      return false if @_dragged.length > 1
      # reset dragged candidate if needed
      @_dragged = [] unless @_dragged.length is 1
      # call inherited method
      $.rheia.authoringMap::_onDragStart.apply @, arguments

    # **private**
    # Returns the DOM node moved by drag'n drop operation within the map.
    # Intended to be inherited, this implementation returns the layer container
    #
    # @param event [Event] the drag start event
    # @return the moved DOM node.
    _mapDragHelper: (event) ->
      moved = @_container
      # move from the map: search for an item wbove position
      offset = @element.offset()
      pos = @getCoord x:event.pageX+@_width-offset.left, y:event.pageY+@_height-offset.top

      @_dragged = []
      for id, widget of @_itemWidgets
        if widget.options.coordinates.x is pos.x and widget.options.coordinates.y is pos.y
          @_dragged.push widget.options.model

      if @_dragged.length is 1
        console.debug "moves instance #{@_dragged[0].id}"
        # creates a drag handler inside body
        moved = utils.dragHelper(@_dragged[0]).appendTo $('body')
        
        # set cursor offset of the drag helper, and avoid helper to be bellow cursor
        @_container.draggable 'option', 'cursorAt',
          left: (@_tileW*@options.zoom/2)-25
          top: (@_tileH*@options.zoom/2)-22
      else
        # reset the drag helper cursor offset
        @_container.draggable 'option', 'cursorAt', null
      moved;

    # **private**
    # Drag handler, that allows drag operation on items going outside widget bounds
    #
    # @param event [Event] drag'n drop mouse event
    # @return false to cancel the drag'n drop operation
    _onDrag: (event) ->
      # call inherited method
      @_draggedInside = $.rheia.authoringMap::_onDrag.apply @, arguments
      # always allows item drag operations
      return true if @_dragged.length is 1
      # otherwise returns inherited result
      @_draggedInside

    # **private**
    # Drag'n drop handler that ends selection or move map. 
    # If an item is dragged inside map, let the `_onDrop` handler affect new coordinates
    # If an item is dragged outside map, does nothing.
    # 
    # @param event [Event] move/selection end event.
    # @param details [Object] moved object details:
    # @option details draggable [Object] operation source
    # @option details helper [Object] moved object
    # @option details position [Object] current position of the moved object
    _onDragStop: (event, details) ->
      if @_dragged.length is 1
        # if inside, do drop. otherwise, does nothing
        if @_draggedInside
          console.log "dragged item #{@_dragged[0].id} inside map"
          @_onDrop event, details 
      else
       $.rheia.authoringMap::_onDragStop.apply @, arguments

    # **private**
    # Map drop handler. Triggers affectation of item types.
    #
    # @param event [Event] move/selection end event.
    # @param details [Object] moved object details:
    # @option details draggable [Object] operation source
    # @option details helper [Object] moved object
    # @option details position [Object] current position of the moved object
    _onDrop: (event, details) ->
      return unless @_cursor
      instance = details?.helper?.data 'instance'
      if instance?
        console.log "drops instance #{instance.id} at coordinates x:#{@_cursor.x}, y:#{@_cursor.y}"
        # we dragged an item inside map
        @_trigger 'affectInstance', event,
          instance: instance
          coord: @_cursor,
          mapId: @options.mapId
      else
        $.rheia.authoringMap::_onDrop.apply @, arguments