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
  'widget/baseWidget'
  'mousewheel'
],  ($, _, utils) ->


  # Base widget for maps that allows drag'n drop affectation and selections
  # Currently, only hexagonal maps are implemented
  $.widget 'rheia.authoringMap', $.rheia.baseWidget,

    options:   

      # delegate object used to draw tiles on map
      renderer: null

      # lower coordinates of the displayed map. Modification triggers the 'coordChanged' event, and reset map content.
      # Read-only, use `setOption('lowerCoord', ...)` to modify.
      lowerCoord: {x:0, y:0}

      # upper coordinates of the displayed map. Automatically updates when upper coordinates changes.
      # Read-only, do not modify manually.
      upperCoord: {x:0, y:0}

      # Awaited with and height for individual tiles, with normal zoom.
      tileDim: 100

      # Number of vertical displayed tiles 
      verticalTileNum: 10

      # Number of horizontal displayed tiles.
      horizontalTileNum: 10

      # Flag that indicates wether or not display the tile grid.
      # Read-only, use `setOption('displayGrid', ...)` to modify.
      displayGrid: true

      # Flag that indicates wether or not display the tile coordinates (every 5 tiles).
      # Read-only, use `setOption('displayMarkers', ...)` to modify.
      displayMarkers: true

      # Coordinates of the selected tiles.
      # Read-only.
      selection: []

      # Current zoom.
      # Read-only, use `setOption('zoom', ...)` to modify.
      zoom: 1
    
      # Minimum zoom
      minZoom: 0.1
    
      # maximum zoom
      maxZoom: 2

      # string used to allow only a specific type of drag'n drop operations
      dndType: null

      # color used for markers, grid, and so on.
      colors:
        selection: '#666'
        markers: 'red'
        grid: '#888'
        hover: '#ccc'

      # angle use to simulate perspective. 60 means view from above. 45 means iso perspective
      angle: 45

    # **private**
    # displayed map content. 
    _data: []

    # **private**
    # Coordinate of the hidden bottom left tile, origin of the map.
    _origin: x:0, y:0

    # **private**
    # Total width of the displayed map.
    _width: 0

    # **private**
    # Total height of the displayed map.
    _height: 0

    # **private**
    # the layer container
    _container: null

    # **private**
    # Position of the start tile while selecting.
    _start: null

    # **priate**
    # Temporary layer that displays the selection.
    _selectLayer: null

    # **private**
    # clone used while loading field data to avoid filtering
    _cloneLayer: null

    # **private**
    # Widget's dimension while drag'n drop operation.
    _dim: null

    # **private**
    # temporary store widget's offset while dragging to save computations
    _offset: null

    # **private**
    # Jumper to avoid refreshing too many times hovered tile.
    _moveJumper: 0

    # **private**
    # last cursor position
    _cursor: null

    # **private**
    # Mousewheel zoom increment.
    _zoomStep: 0.05
    
    # **private**
    # Timer to avoid zooming too many times.
    _zoomTimer: null

    # **private**
    # Array of loading images.
    _loadedImages : []

    # **private**
    # Number of loading images before removing the temporary field layer 
    _pendingImages: 0
  
    # **private**
    # enable selection
    _selectable: true

    # Adds field to map. Will be effective only if the field is inside displayed bounds.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param added [Array<Object>] added data (JSON array). 
    addData: (added) ->
      o = @options
      for data in added
        if data.x >= o.lowerCoord.x and data.x <= o.upperCoord.x and data.y >= o.lowerCoord.y and data.y <= o.upperCoord.y
          @_data.push data
          img = "/images/#{data.typeId}-#{data.num}.png"
          unless img in @_loadedImages
            @_loadedImages.push img
            @_pendingImages++
            # data is inside displayed bounds: loads it
            rheia.router.trigger 'loadImage', img 

    # Removes field from map. Will be effective only if the field was displayed.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param removed [Field] removed data (JSON array). 
    removeData: (removed) ->
      o = @options     
      ctx = @element.find('.fields')[0].getContext '2d'
      for data in removed
        if data.x >= o.lowerCoord.x and data.x <= o.upperCoord.x and data.y >= o.lowerCoord.y and data.y <= o.upperCoord.y
          # draw white tile at removed field coordinate
          o.renderer.drawTile ctx, data, 'white'
          # removes from local cache
          for field, i in @_data when field._id is data._id
            @_data.splice i, 1
            break

    # Allows renderer to get map internal dimensions
    #
    # @return map inner dimension:
    # @option height [Number] the total map height, which is 3 times the displayed height
    # @option width [Number] the total map width, which is 3 times the displayed width
    # @option origin [Object] the map coordinate of the lower-left corner of the map
    # @option verticalTotalNum [Number] number of tile within the displayed height
    mapRefs: ->
      {
        height: @_height*3
        width: @_width*3
        origin: @_origin
        verticalTotalNum: @_verticalTotalNum()
      }

    # **private**
    # Build rendering
    _create: ->
      $.rheia.baseWidget::_create.apply @, arguments

      # Initialize internal state
      @_origin = x:0, y:0
      @_width = 0
      @_height = 0
      @_container = null
      @_start = null
      @_selectLayer = null
      @_cloneLayer = null
      @_dim = null
      @_offset = null
      @_moveJumper = 0
      @_cursor = null
      @_zoomTimer = null
      @_loadedImages  = []
      @_pendingImages = 0

      @element.empty().removeClass().addClass 'map-widget'
      o = @options
      return unless o.renderer?

      # dimensions depends on the map kind.
      @_computeDimensions()

      @element.css(
        height: @_height
        width: @_width
      ).mousewheel (event, delta) => 
        @_zoom @options.zoom + delta*@_zoomStep
        event?.preventDefault()
        return false

      # creates the layer container, 3 times bigger to allow drag operations
      @_container = $('<div class="map-perspective"></div>').css(
        height: @_height*3
        width: @_width*3
        top: -@_height
        left: -@_width
      ).draggable(
        distance: 5
        scope: o.dndType
        helper: (event) => @_mapDragHelper event
        start: (event) => @_onDragStart event
        drag: (event) => @_onDrag event
        stop: (event, details) => @_onDragStop event, details
      ).on('click', (event) =>
        @_onClick event
      ).on('mousemove', (event) => 
        return unless @_moveJumper++ % 3 is 0
        @_cursor = @options.renderer.posToCoord @_mousePos event
        @_drawCursor()
      ).on('mouseleave', (event) => 
        @_cursor = null
        @_drawCursor()
      ).appendTo @element

      # creates the field canvas element      
      $("""<canvas class="fields movable" height="#{@_height*3}" width="#{@_width*3}"></canvas>""").droppable(
        scope: o.dndType
        drop: (event, details) => @_onDrop event, details
      ).appendTo @_container

      # creates the grid canvas element      
      $("""<canvas class="selection" height="#{@_height*3}" width="#{@_width*3}"></canvas>""").appendTo @_container if @_selectable
      $("""<canvas class="grid" height="#{@_height*3}" width="#{@_width*3}"></canvas>""").appendTo @_container
      $("""<canvas class="markers" height="#{@_height*3}" width="#{@_width*3}"></canvas>""").appendTo @_container
      $("""<canvas class="hover" height="#{@_height*3}" width="#{@_width*3}"></canvas>""").appendTo @_container

      @_container.find('canvas').css
        width: "#{@_width*3}px"
        height: "#{@_height*3}px"

      @_drawGrid()
      @_drawMarkers()

      # image loading loading handler
      @bindTo rheia.router, 'imageLoaded', => @_onImageLoaded.apply @, arguments
  
      # gets first data
      setTimeout =>
        @setOption 'lowerCoord', o.lowerCoord
      , 0

    # **private**
    # Method invoked when the widget options are set. Update rendering if `current` or `images` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.rheia.baseWidget::_setOption.apply @, arguments unless key in ['renderer', 'lowerCoord', 'displayGrid', 'displayMarkers', 'zoom']
      o = @options
      o[key] = value
      switch key
        when 'renderer'
          @_create() if value?
        when 'lowerCoord'
          # computes lower coordinates
          o.upperCoord = 
            x: value.x + Math.ceil @_width/o.renderer.tileW
            y: value.y + Math.ceil @_height/o.renderer.tileH
          @_origin = 
            x: value.x - Math.floor @_width/o.renderer.tileW
            y: value.y - Math.floor @_height/o.renderer.tileH
          # creates a clone layer while reloading
          @_cloneLayer = $("<canvas width=\"#{@_width*3}\" height=\"#{@_height*3}\"></canvas>")
          # empty datas
          @_data = []
          @_trigger 'coordChanged'
        when 'displayGrid'
          @_drawGrid()
        when 'displayMarkers'
          @_drawMarkers()
        when 'zoom'
          # change zoom without triggering the event
          @_zoom @options.zoom, true

    # **private**
    # Returns the number of tile within the map total height.
    # Used to reverse the ordinate axis.
    # Intended to be inherited, this implementation returns the layer container
    #
    # @param event [Event] the drag start event
    # @return the moved DOM node.
    _verticalTotalNum: () -> 
      -1 + Math.floor @_height*3/@options.renderer.tileH

    # **private**
    # Returns the DOM node moved by drag'n drop operation within the map.
    # Intended to be inherited, this implementation returns the layer container
    #
    # @param event [Event] the drag start event
    # @return the moved DOM node.
    _mapDragHelper: (event) -> 
      @_container

    # **private**
    # Extracts mouse position from DOM event, regarding the container.
    # @param event [Event] 
    # @return the mouse position
    # @option return x the abscissa position
    # @option return y the ordinate position
    _mousePos: (event) ->
      offset = @_container.offset()
      {
        x: event.pageX-offset.left
        y: event.pageY-offset.top
      }

    # **private**
    # If no image loading remains, and if a clone layer exists, then its content is 
    # copied into the field layer
    _replaceFieldClone: ->
      o = @options
      # only if no image loading is pendinf
      return unless @_pendingImages is 0 and @_cloneLayer?
      # all images were rendered on clone layer: copy it on field layer.
      fieldLayer = @_container.find '.fields'
      fieldLayer.css top:0, left:0
      canvas = fieldLayer[0]
      canvas.width = canvas.width
      canvas.getContext('2d').putImageData @_cloneLayer[0].getContext('2d').getImageData(0, 0, @_width*3, @_height*3), 0, 0
      @_cloneLayer.remove()
      @_cloneLayer = null

    # **private**
    # Allows sub-classes to compute individual tiles and map dimensions, without using zoom.
    # Must set attributes `_width`, `_height` and `_origin`
    _computeDimensions: ->
      # horizontal hexagons: side length of an hexagon.
      s = @options.tileDim/2

      o = @options
      o.renderer.init @

      # canvas dimensions (add 1 to take in account stroke width, and no zoom)
      @_width = 1+o.horizontalTileNum*o.renderer.tileW/o.zoom
      @_height = 1+o.verticalTileNum*o.renderer.tileH/o.zoom 

      @_origin = 
        x: o.lowerCoord.x - Math.floor @_width/o.renderer.tileW
        y: o.lowerCoord.y - Math.floor @_height/o.renderer.tileH

    # **private**
    # Redraws the grid wireframe.
    _drawGrid: ->
      canvas = @element.find('.grid')[0]
      ctx = canvas.getContext '2d'
      canvas.width = canvas.width
      o = @options
      return unless o.displayGrid

      ctx.strokeStyle = o.colors.grid 
      o.renderer.drawGrid ctx

    # **private**
    # Redraws the grid markers.
    _drawMarkers: ->
      canvas = @element.find('.markers')[0]
      ctx = canvas.getContext '2d'
      canvas.width = canvas.width
      o = @options
      return unless o.displayMarkers

      ctx.font = "#{15*o.zoom}px sans-serif"
      ctx.fillStyle = o.colors.markers
      ctx.textAlign = 'center'
      ctx.textBaseline  = 'middle'
      o.renderer.drawMarkers ctx

    # **private**
    # Draws the current selection on the selection layer
    _drawSelection: ->
      return unless @_selectable
      console.log 'redraws map selection'
      # clear selection
      canvas = @element.find('.selection')[0]
      ctx = canvas.getContext '2d'
      canvas.width = canvas.width
      ctx.fillStyle = @options.colors.selection
      @options.renderer.drawTile ctx, selected, @options.colors.selection for selected in @options.selection

    # **private**
    # Redraws cursor on stored position (@_cursor)
    _drawCursor: ->
      canvas = @element.find('.hover')[0]
      canvas.width = canvas.width
      return unless @_cursor
      @options.renderer.drawTile canvas.getContext('2d'), @_cursor, @options.colors.hover

    # **private**
    # Allows to zoom in and out the map
    # 
    # @param zoom [Number] the new zoom value.
    # @param noEvent [Boolean] do not change rendering, used when setting zoom programmatically.
    _zoom: (zoom, noEvent) ->
      o = @options
      # avoid weird values by rounding.
      zoom = Math.round(zoom*100)/100;
      # round to normal zoom if we approch
      if zoom > 1-@_zoomStep and zoom < 1+@_zoomStep
        zoom = 1
      
      # stay within allowed bounds
      if zoom < 1
        zoom = Math.max zoom, o.minZoom
      else
        zoom = Math.min zoom, o.maxZoom
      
      console.log "new map zoom: #{zoom}"
      if noEvent or zoom != o.zoom
        # stop running timer
        clearTimeout @_zoomTimer if @_zoomTimer
        o.zoom = zoom
        # computes again current dimensions
        @_computeDimensions()

        # redraws everything
        @_drawGrid()
        @_drawMarkers()
        @_drawSelection()
        @_drawCursor()

        # redraws totally the field layer
        canvas = @_container.find('.fields')[0]
        canvas.width = canvas.width
        tmp = @_data
        @_data = []
        @addData tmp

        # trigger event
        @_trigger 'zoomChanged' unless noEvent
        # and reload coordinages
        @_zoomTimer = setTimeout =>
          # compute new lowerCoord
          o = @options
          newCoord =
            x: @_origin.x+Math.floor @_width/o.renderer.tileW
            y: @_origin.y+Math.floor @_height/o.renderer.tileH
          console.log "map zoom ends on x: #{newCoord.x} y:#{newCoord.y}"
          @setOption 'lowerCoord', newCoord
        , 300

    # **private**
    # Image loading end handler. Draws it on the field layer, and if it's the last awaited image, 
    # remove field clone layer.
    #
    # @param success [Boolean] true if image was successfully loaded
    # @param src [String] the loaded image url
    # @param img [Image] an Image object, null in case of failure
    _onImageLoaded: (success, src, img) -> 
      o = @options
      # do nothing if loading failed.
      return unless src in @_loadedImages
      @_loadedImages.splice @_loadedImages.indexOf(src), 1
      src = src.slice src.lastIndexOf('/')+1
      @_pendingImages--
        
      return @_replaceFieldClone() unless success
        
      ctx = @element.find('.fields')[0].getContext '2d'
      # write on field layer, unless a clone layer exists
      ctx = @_cloneLayer[0].getContext '2d' if @_cloneLayer?

      # looks for data corresponding to this image
      for data in @_data
        if "#{data.typeId}-#{data.num}.png" is src
          {left, top} = o.renderer.coordToPos data
          ctx.drawImage img, left, top, o.renderer.tileRenderW+1, o.renderer.tileRenderH+1
      # all images was loaded: remove temporary field layer
      @_replaceFieldClone()
          
    # **private**
    # Map drop handler. Triggers affectation.
    #
    # @param event [Event] move/selection end event.
    # @param details [Object] moved object details:
    # @option details draggable [Object] operation source
    # @option details helper [Object] moved object
    # @option details position [Object] current position of the moved object
    _onDrop: (event, details) ->
      o = this.options
      return unless @_cursor
      # extract dragged datas
      idx = details.helper.data 'idx'
      id = details.helper.data 'id'
      # indicates if it's in selection or not
      inSelection = false
      if @_selectable
        for selected in o.selection when selected.x is @_cursor.x and selected.y is @_cursor.y
          inSelection = true
          break
      console.log "drops images #{idx} of field #{id} at coordinates x:#{@_cursor.x}, y:#{@_cursor.y}, in selection: #{inSelection}"
      # triggers affectation.
      @_trigger 'affect', event,
        typeId: id
        num: idx,
        coord: @_cursor,
        inSelection: inSelection and o.selection.length isnt 0
    
    # **private**
    # Drag'n drop start handler. Keep the widget dimensions, and the start tile for selections.
    # It cancels the jQuery drag'n drop operation if it's a selection, and handle it manually.
    #
    # @param event [Event] drag'n drop start mouse event
    # @return false to cancel the jQuery drag'n drop operation
    _onDragStart: (event) ->
      o = @options
      # computes the absolute position and dimension of the widget
      offset = @element.offset()
      @_dim = $.extend {}, offset
      @_dim.right = @_dim.left + @_width
      @_dim.bottom = @_dim.top + @_height

      cancel = false
      # keeps the start coordinate for a selection
      if event.shiftKey and @_selectable
        @_offset = offset
        @_start = o.renderer.posToCoord
          x: event.pageX+@_width-@_offset.left
          y: event.pageY+@_height-@_offset.top
        # adds a layer to draw selection
        @_selectLayer = @element.find('.selection').clone()
        @_container.append @_selectLayer
        @_onDragTemp = (event) => @_onDrag event
        @_onSelectionEndTemp = (event) => @_onSelectionEnd event
        $(document).mousemove @_onDragTemp
        $(document).mouseup @_onSelectionEndTemp
        cancel = true

        # empties current selection
        if !event.ctrlKey
          o.selection = []
          @_drawSelection()
      
      !cancel
    
    # **private**
    # Drag handler, that ends the operation if the mouse quit the widget's bounds.
    # Displays selection rectangle if necessary
    #
    # @param event [Event] drag'n drop mouse event
    # @return false to cancel the drag'n drop operation
    _onDrag: (event) ->
      o = @options
      while !('pageX' of event) 
        event = event.originalEvent
      
      mouse = left: event.pageX, top: event.pageY
      if mouse.left < @_dim.left || mouse.left > @_dim.right || 
          mouse.top < @_dim.top || mouse.top > @_dim.bottom
        # we left the widget, stops the operation
        if @_start
          @_onSelectionEnd event
        return false

      # draws temporary selection
      if @_start and @_selectLayer
        # compute temporary end of the selectionEvalue la fin temporaire de la séléction
        end = o.renderer.posToCoord 
          x: event.pageX+@_width-@_offset.left
          y: event.pageY+@_height-@_offset.top
        lower =
          x: Math.min end.x, @_start.x
          y: Math.min end.y, @_start.y
        higher =
          x: Math.max end.x, @_start.x
          y: Math.max end.y, @_start.y
        canvas = @_selectLayer[0]
        ctx = canvas.getContext '2d'
        canvas.width = canvas.width
        # walk through selected tiles
        for x in [lower.x..higher.x]
          for y in [lower.y..higher.y]
            @options.renderer.drawTile ctx, {x:x, y:y}, @options.colors.selection
      true
    
    # **private**
    # Drag'n drop handler that ends selection or move map.
    #
    # @param event [Event] move/selection end event.
    # @param details [Object] moved object details:
    # @option details draggable [Object] operation source
    # @option details helper [Object] moved object
    # @option details position [Object] current position of the moved object
    _onDragStop: (event, details) ->
      delete this.options._dim
      if event.shiftKey and @_selectable
        # selection end
        @_onSelectionEnd event
      else
        # move end
        o = @options
        
        # get the movement's width and height
        reference = o.renderer.posToCoord x:@_width, y:@_height
        pos = 
          x:-parseInt @_container.css 'left'
          y:-parseInt @_container.css 'top'
        move = o.renderer.posToCoord pos
        move.x -= reference.x
        move.y -= reference.y

        # update widget coordinates
        o.lowerCoord.x += move.x
        o.lowerCoord.y += move.y
        @_origin = 
          x: o.lowerCoord.x - Math.floor @_width/o.renderer.tileW
          y: o.lowerCoord.y - Math.floor @_height/o.renderer.tileH

        # redraws everything
        @_drawGrid()
        @_drawMarkers()
        @_drawSelection()
        @_drawCursor()

        # place fields layer because it will be redrawn once all new content would have been retrieved 
        # shift to right on even rows
        shift = unless move.y%2 then 0 else if @_origin.y%2 then -1 else 1
        @_container.find('.movable').css
          left: (0.5*shift-move.x)*o.renderer.tileW
          top: move.y*o.renderer.tileH

        # place the container to only animate along a single tile dimension and run the end animation
        @_container.css
          left: -@_width+(pos.x/o.renderer.tileW)-(pos.x%o.renderer.tileW)
          top: -@_height+(pos.y/o.renderer.tileH)-(pos.y%o.renderer.tileH)
        @_container.transition
          left: -@_width
          top: -@_height
        , 200, =>
          # reloads map
          console.log "map move ends on x:#{o.lowerCoord.x} y:#{o.lowerCoord.y}"
          @setOption 'lowerCoord', o.lowerCoord

    # **private**
    # Drag'n drop selection end handler.
    # Adds all selected tiles to current selection and redraws it
    # @param event [Event] drag'n drop selection end event
    _onSelectionEnd: (event) ->
      o = @options
      # unbinds temporary handlers
      $(document).unbind 'mousemove', @_onDragTemp
      $(document).unbind 'mouseup', @_onSelectionEndTemp
      return unless @_start

      # removes temporary layer
      @_selectLayer.remove()
      # compute end coordinate
      end = o.renderer.posToCoord 
        x: event.pageX+@_width-@_offset.left
        y: event.pageY+@_height-@_offset.top
      console.log "selection between x:#{@_start.x} y:#{@_start.y} and x:#{end.x} y:#{end.y}"

      lower =
        x: Math.min end.x, @_start.x
        y: Math.min end.y, @_start.y
      higher =
        x: Math.max end.x, @_start.x
        y: Math.max end.y, @_start.y
      # walk through selected tiles
      for x in [lower.x..higher.x]
        for y in [lower.y..higher.y]
          found = false
          (found = true; break) for tile in o.selection when tile.x is x and tile.y is y
          o.selection.push x:x, y:y unless found
      @_start = null;
      # redraw selection
      @_drawSelection()
      @_trigger 'selectionChanged'

    # **private**
    # Click handler that toggle the clicked tile from selection if the ctrl key is pressed
    # @param event [Event] click event
    _onClick: (event) ->
      return unless @_selectable
      coord = @options.renderer.posToCoord @_mousePos event
      console.log "click on tile x:#{coord.x} y:#{coord.y} with control key #{event.ctrlKey}"
      add = true
      if event.ctrlKey
        # search in selection
        for tile, i in @options.selection when tile.x is coord.x and tile.y is coord.y
          add = false
          @options.selection.splice i, 1
          break
      else
        # empties selection
        @options.selection = []

      # selects the clicked tile and redraw
      @options.selection.push coord if add
      @_drawSelection()
      @_trigger 'selectionChanged'


  # The map renderer is used to render tiles on the map
  # Extending this class allows to have different tiles type: hexagonal, diamond...
  class MapRenderer

    # associated map widget
    map: null

    # Individual tile width, taking zoom into account
    # Used for tile displayal, may have overlapping with other tiles.
    tileRenderH: null

    # Individual tile height, taking zoom into account
    # Used for tile displayal, may have overlapping with other tiles.
    tileRenderH: null

    # Individual tile width, taking zoom into account
    # Used for tile displayal, may have overlapping with other tiles.
    tileW: null

    # Individual tile height, taking zoom into account
    # Used to compute stuff within map, without any overlapping
    tileH: null
    
    # Initiate the renderer with map inner state. 
    # Initiate `tileW` and `tileH`.
    #
    # @param map [Object] the associated map widget
    # 
    init: (map) => throw new Error 'the `init` method must be implemented'

    # Translate map coordinates to css position (relative to the map origin)
    #
    # @param coord [Object] object containing x and y coordinates
    # @option coord x [Number] object abscissa
    # @option coord y [Number] object ordinates
    # @return an object containing:
    # @option return left [Number] the object's left offset, relative to the map origin
    # @option return top [Number] the object's top offset, relative to the map origin
    coordToPos: (obj) => throw new Error 'the `coordToPos` method must be implemented'

    # Translate css position (relative to the map origin) to map coordinates to css position
    #
    # @param coord [Object] object containing top and left position relative to the map origin
    # @option coord left [Number] the object's left offset
    # @option coord top [Number] the object's top offset
    # @return an object containing:
    # @option return x [Number] object abscissa
    # @option return y [Number] object ordinates
    # @option return z-index [Number] the object's z-index
    posToCoord: (pos) => throw new Error 'the `posToCoord` method must be implemented'

    # Draws the grid wireframe on a given context.
    #
    # @param ctx [Object] the canvas context on which drawing
    drawGrid: (ctx) => throw new Error 'the `drawGrid` method must be implemented'

    # Draws the markers on a given context.
    #
    # @param ctx [Object] the canvas context on which drawing
    drawMarkers: (ctx) => throw new Error 'the `drawMarkers` method must be implemented'

    # Draw a single selected tile in selection or to highlight hover
    #
    # @param ctx [Canvas] the canvas context.
    # @param pos [Object] coordinate of the drew tile
    # @param color [String] the color used to fill the tile
    drawTile: (ctx, pos, color) -> throw new Error 'the `drawTile` method must be implemented'
