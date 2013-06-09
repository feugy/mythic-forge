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
  'i18n!nls/widget'
  'widget/authoringMap'
  'widget/mapItem'
  'widget/toggleable'
],  ($, _, utils, i18n, Map) ->

  # Specific map that adds items support to authoring Map, and remove selection features
  # triggers an `itemClicked` event with model as attribute when clicked
  class ModerationMap extends Map.Widget
    
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
    # layer that holds items while loading new map
    _itemCloneLayer: null

    # **private**
    # stores items rendering, organized by item id, while loading new map
    _cloneWidgets: {}

    # **private**
    # Number of pending loading items 
    _loading: 0

    # **private**
    # Dragged item candidates
    _dragged: []

    # **private**
    # Flag to indicate wether the dragged item is inside or outside the widget
    _draggedInside: false

    # **private**
    # menu that displays multiple items on the same tile.
    _popupMenu: null

    # Adds field or items to map. Will be effective only if the objects is inside displayed bounds.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param added [Array<Object>] added data (JSON array). 
    addData: (added) =>
      o = @options
      # separate fields from items
      fields = []
      for obj in added
        if !(obj.get?)
          # zoom case: reinject existing fields
          fields.push obj
        else if !(obj._className?)
          fields.push obj.toJSON() if o.mapId is obj.mapId
        else if obj._className is 'Item' and o.mapId is obj.map?.id
          id = obj.id
          #do not add same widget twice
          return if @_itemWidgets[id]?
          @_loading++
          # creates widget for this item
          @_itemWidgets[id] = $("<span data-id='#{id}'></span>").mapItem(
            model: obj
            map: @
          ).on('loaded', firstLoading = =>
            # only relevant on first loading
            @_itemWidgets[id]?.$el?.off 'loaded', firstLoading
            @_loading--
            @_endLoading()
          ).on('dispose', (event, widget) =>
            delete @_itemWidgets[id]
          ).appendTo(@_itemLayer).data 'mapItem'
      
      # let superclass manage fields
      super fields if fields.length > 0

    # Checks if the corresponding item is displayed or not
    # 
    # @param item [Object] checked item
    # @return true if the map contains a mapItem widget that displays this item
    hasItem: (item) =>
      @_itemWidgets[item?.id]?

    # Removes field or itemsfrom map. Will be effective only if the field was displayed.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param removed [Field] removed data (JSON array). 
    removeData: (removed) =>
      # separate fields from items
      fields = []
      for obj in removed
        if obj._className is 'Item'
          # immediately removes corresponding widget. Will trigger 'dispose' event
          @_itemWidgets[obj.id]?.$el.remove()
        else unless obj._className?
          fields.push obj.toJSON() if @options.mapId is obj.mapId

      # let superclass manage fields
      super fields if fields.length > 0
          
    # Method invoked when the widget options are set. Update rendering if `current` or `images` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) =>
      switch key
        when 'mapId'
          if @options.mapId isnt value
            # reset all items rendering.
            widget.$el.remove() for id, widget of @_itemWidgets
            @_itemWidgets = {}

      # superclass inherited behaviour
      super key, value

    # Removes created popup menu
    dispose: =>
      @_popupMenu?.$el.off 'click'
      @_popupMenu?.$el.remove()
      super()

    # **private**
    # Build rendering
    _create: =>
      # superclass call
      super()

      # adds the item layer.    
      @_itemLayer = $("<div class='items movable'></div>").appendTo @_container
      if @options.renderer?
        @_itemLayer.css
          height: @options.renderer.height*3
          width: @options.renderer.width*3

    #**private**
    # While reloading all data, add a clone to avoid flickering
    _cloneContent: =>
      super()
      @_cloneWidgets = @_itemWidgets
      @_itemCloneLayer = @_itemLayer
      @_itemLayer = $("<div class='items movable'></div>").css
        height: @options.renderer.height*3
        width: @options.renderer.width*3
      @_itemWidgets = {}

    # **private**
    # If no image loading remains, and if a clone layer exists, then its content is 
    # copied into the field layer
    _endLoading: =>
      super()
      return unless @_loading is 0 and @_itemCloneLayer?
      # unregister dispose event handler
      widget.$el.off 'dispose' for id, widget of @_cloneWidgets
      @_cloneWidgets = null
      # remove clones
      @_container.find('.items').remove()
      @_itemCloneLayer = null
      # place new clone layer
      @_itemLayer.appendTo @_container
      

    # **private**
    # Returns the DOM node moved by drag'n drop operation within the map.
    # Intended to be inherited, this implementation returns the layer container
    #
    # @param event [Event] the drag start event
    # @return the moved DOM node.
    _mapDragHelper: (event) =>
      moved = @_container
      # move from the map: search for an item wbove position
      offset = @$el.offset()
      pos = @options.renderer.posToCoord 
        left: event.pageX+@options.renderer.width-offset.left
        top: event.pageY+@options.renderer.height-offset.top

      @_dragged = []
      if @_popupMenu?
        # drag from multiple menu
        id = $(event.target).closest('li').data 'id'
        @_dragged.push @_itemWidgets[id].options.model if @_itemWidgets[id]?
      else
        # drag from the map
        for id, widget of @_itemWidgets
          if widget.options.coordinates.x is pos.x and widget.options.coordinates.y is pos.y
            @_dragged.push widget.options.model

      if @_dragged.length is 1
        console.debug "moves instance #{@_dragged[0].id}"
        # creates a drag handler inside body
        moved = utils.dragHelper(@_dragged[0]).appendTo $('body')
        
        # set cursor offset of the drag helper, and avoid helper to be bellow cursor
        @_container.draggable 'option', 'cursorAt',
          left: (@options.tileDim*@options.zoom/2)-25
          top: (@options.tileDim*@options.zoom/2)-22
      else
        # reset the drag helper cursor offset
        @_container.draggable 'option', 'cursorAt', null
      moved

    # **private**
    # Drag'n drop start handler. Allow to drag items if item selected.
    #
    # @param event [Event] drag'n drop start mouse event
    # @return false to cancel the jQuery drag'n drop operation
    _onDragStart: (event) =>
      #  cancels drag if we have multiple dragged target
      return false if @_dragged.length > 1
      # reset dragged candidate if needed
      @_dragged = [] unless @_dragged.length is 1
      # call inherited method
      super event

    # **private**
    # Drag handler, that allows drag operation on items going outside widget bounds
    #
    # @param event [Event] drag'n drop mouse event
    # @return false to cancel the drag'n drop operation
    _onDrag: (event) =>
      # call inherited method
      @_draggedInside = super event
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
    _onDragStop: (event, details) =>
      @_popupMenu?.$el.off 'click'
      @_popupMenu?.$el.remove()
      if @_dragged.length is 1
        # if inside, do drop. otherwise, does nothing
        if @_draggedInside
          console.log "dragged item #{@_dragged[0].id} inside map"
          @_onDrop event, details 
      else
       super event, details

    # **private**
    # Map drop handler. Triggers affectation of item types.
    #
    # @param event [Event] move/selection end event.
    # @param details [Object] moved object details:
    # @option details draggable [Object] operation source
    # @option details helper [Object] moved object
    # @option details position [Object] current position of the moved object
    _onDrop: (event, details) =>
      return unless @_cursor
      instance = details?.helper?.data 'instance'
      if instance?
        console.log "drops instance #{instance.id} at coordinates x:#{@_cursor.x}, y:#{@_cursor.y}"
        # we dragged an item inside map
        @$el.trigger 'affectInstance',
          instance: instance
          coord: @_cursor,
          mapId: @options.mapId
      else
        super event, details

    # **private**
    # Click handler that toggle the clicked tile from selection if the ctrl key is pressed
    # @param event [Event] click event
    _onClick: (event) =>
      coord = @options.renderer.posToCoord @_mousePos event
      @_popupMenu?.$el.off 'click'
      @_popupMenu?.$el.remove()
      # stop if comming from the popup menu to avoid opening something else
      return if $(event.target).closest('.menu').length isnt 0

      @_clicked = []
      for id, widget of @_itemWidgets
        if widget.options.coordinates.x is coord.x and widget.options.coordinates.y is coord.y
          @_clicked.push widget.options.model

      if @_clicked.length is 1
        # trigger item opening
        @$el.trigger 'itemClicked', @_clicked[0]
      else if @_clicked.length > 1
        # stops event to avoid closing menu immediately
        event.preventDefault()
        event.stopImmediatePropagation()
        content = ''
        for model in @_clicked
          content += "<li data-id='#{model.id}'>#{_.sprintf i18n.instanceDetails.name, utils.instanceName(model), model.id}</li>"
        # opens a contextual menu with possible items
        @_popupMenu = $("<ul class='menu'>#{content}</ul>").appendTo(@_container).toggleable(
          destroyOnClose: true
          destroy: => @_popupMenu = null
        ).data 'toggleable'
        @_popupMenu.open event.pageX+5, event.pageY+5

        # adds a click handler inside menu
        @_popupMenu.$el.on 'click', (event) =>
          id = $(event.target).closest('li').data 'id'
          return unless id?
          event.preventDefault()
          @$el.trigger 'itemClicked', @_itemWidgets[id].options.model

  # widget declaration
  ModerationMap._declareWidget 'moderationMap', $.fn.authoringMap.defaults