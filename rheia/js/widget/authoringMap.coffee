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
  'widget/base'
  'mousewheel'
],  ($, _, utils, Base) ->


  # Base widget for maps that allows drag'n drop affectation and selections.
  # It delegates rendering operations to a mapRenderer that you need to manually create and set.
  class AuthoringMap extends Base

    # **private**
    # displayed map content. 
    _data: []

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

    # Build rendering
    constructor: (element, options) ->
      super element, options
      @_create()

    # Adds field to map. Will be effective only if the field is inside displayed bounds.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param added [Array<Object>] added data (JSON array). 
    addData: (added) =>
      o = @options
      for data in added
        if o.mapId is data.mapId and data.x >= o.lowerCoord.x and data.x <= o.upperCoord.x and data.y >= o.lowerCoord.y and data.y <= o.upperCoord.y
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
    removeData: (removed) =>
      o = @options     
      ctx = @$el.find('.fields')[0].getContext '2d'
      for data in removed
        if o.mapId is data.mapId and data.x >= o.lowerCoord.x and data.x <= o.upperCoord.x and data.y >= o.lowerCoord.y and data.y <= o.upperCoord.y
          # draw white tile at removed field coordinate
          o.renderer.drawTile ctx, data, 'white'
          # removes from local cache
          for field, i in @_data when field._id is data._id
            @_data.splice i, 1
            break

    # Returns data corresponding to a given coordinate
    # 
    # @param coord [Object] checked coordinates
    # @return the corresponding data or null.
    getData: (coord) =>
      return data for data in @_data when data.x is coord.x and data.y is coord.y
      null

    # Method invoked when the widget options are set. Update rendering if `current` or `images` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) =>
      return unless key in ['renderer', 'lowerCoord', 'displayGrid', 'displayMarkers', 'zoom', 'mapId']
      o = @options
      old = o[key]
      o[key] = value
      switch key
        when 'renderer'
          if value?
            @_create()
          else
            # restore previous renderer
            o[key] = old
        when 'mapId'
          if old isnt value
            # reset all rendering: fields and items.
            canvas = @$el.find('.fields')[0]
            canvas.width = canvas.width
        when 'lowerCoord'
          # computes lower coordinates
          o.upperCoord = o.renderer.nextCorner o.lowerCoord
          console.log "new displayed coord: ", o.lowerCoord, ' to: ', o.upperCoord
          # creates a clone layer while reloading
          @_cloneLayer = $("<canvas width=\"#{o.renderer.width*3}\" height=\"#{o.renderer.height*3}\"></canvas>")
          # empty datas
          @_data = []
          @$el.trigger 'coordChanged'
        when 'displayGrid'
          @_drawGrid()
        when 'displayMarkers'
          @_drawMarkers()
        when 'zoom'
          # change zoom without triggering the event
          @_zoom @options.zoom, true

    # **private**
    # Re-builds rendering
    _create: =>

      # Initialize internal state
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

      @$el.empty().removeClass().addClass 'map-widget'
      o = @options
      return unless o.renderer?
      o.renderer.init @

      @$el.css(
        height: o.renderer.height
        width: o.renderer.width
      ).mousewheel (event, delta) => 
        @_zoom @options.zoom + delta*@_zoomStep
        event?.preventDefault()
        return false

      # creates the layer container, 3 times bigger to allow drag operations
      @_container = $('<div class="map-perspective"></div>').css(
        height: o.renderer.height*3
        width: o.renderer.width*3
        top: -o.renderer.height
        left: -o.renderer.width
      ).draggable(
        distance: 5
        scope: o.dndType
        helper: @_mapDragHelper
        start: @_onDragStart
        drag: @_onDrag
        stop: @_onDragStop
      ).on('click', @_onClick
      ).on('mousemove', (event) => 
        return unless @_moveJumper++ % 3 is 0
        @_cursor = @options.renderer.posToCoord @_mousePos event
        @_drawCursor()
      ).on('mouseleave', (event) => 
        @_cursor = null
        @_drawCursor()
      ).appendTo @$el

      # creates the field canvas element      
      $("""<canvas class="fields movable" height="#{o.renderer.height*3}" width="#{o.renderer.width*3}"></canvas>""").droppable(
        scope: o.dndType
        drop: @_onDrop
      ).appendTo @_container

      # creates the grid canvas element      
      $("""<canvas class="selection" height="#{o.renderer.height*3}" width="#{o.renderer.width*3}"></canvas>""").appendTo @_container if @_selectable
      $("""<canvas class="grid" height="#{o.renderer.height*3}" width="#{o.renderer.width*3}"></canvas>""").appendTo @_container
      $("""<canvas class="markers" height="#{o.renderer.height*3}" width="#{o.renderer.width*3}"></canvas>""").appendTo @_container
      $("""<canvas class="hover" height="#{o.renderer.height*3}" width="#{o.renderer.width*3}"></canvas>""").appendTo @_container

      @_container.find('canvas').css
        width: "#{o.renderer.width*3}px"
        height: "#{o.renderer.height*3}px"

      @_drawGrid()
      @_drawMarkers()

      # image loading loading handler
      @bindTo rheia.router, 'imageLoaded', @_onImageLoaded
  
      # gets first data
      _.defer => @setOption 'lowerCoord', o.lowerCoord

    # **private**
    # Returns the DOM node moved by drag'n drop operation within the map.
    # Intended to be inherited, this implementation returns the layer container
    #
    # @param event [Event] the drag start event
    # @return the moved DOM node.
    _mapDragHelper: (event) => 
      @_container

    # **private**
    # Extracts mouse position from DOM event, regarding the container.
    # @param event [Event] 
    # @return the mouse position
    # @option return left the left offset relative to container
    # @option return top the top offset relative to container
    _mousePos: (event) =>
      offset = @_container.offset()
      {
        left: event.pageX-offset.left
        top: event.pageY-offset.top
      }

    # **private**
    # If no image loading remains, and if a clone layer exists, then its content is 
    # copied into the field layer
    _replaceFieldClone: =>
      o = @options
      # only if no image loading is pendinf
      return unless @_pendingImages is 0 and @_cloneLayer?
      # all images were rendered on clone layer: copy it on field layer.
      fieldLayer = @_container.find '.fields'
      fieldLayer.css top:0, left:0
      canvas = fieldLayer[0]
      canvas.width = canvas.width
      canvas.getContext('2d').putImageData @_cloneLayer[0].getContext('2d').getImageData(0, 0, o.renderer.width*3, o.renderer.height*3), 0, 0
      @_cloneLayer.remove()
      @_cloneLayer = null

    # **private**
    # Redraws the grid wireframe.
    _drawGrid: =>
      canvas = @$el.find('.grid')[0]
      ctx = canvas.getContext '2d'
      canvas.width = canvas.width
      o = @options
      return unless o.displayGrid

      ctx.strokeStyle = o.colors.grid 
      o.renderer.drawGrid ctx

    # **private**
    # Redraws the grid markers.
    _drawMarkers: =>
      canvas = @$el.find('.markers')[0]
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
    _drawSelection: =>
      return unless @_selectable
      console.log 'redraws map selection'
      # clear selection
      canvas = @$el.find('.selection')[0]
      ctx = canvas.getContext '2d'
      canvas.width = canvas.width
      ctx.fillStyle = @options.colors.selection
      @options.renderer.drawTile ctx, selected, @options.colors.selection for selected in @options.selection

    # **private**
    # Redraws cursor on stored position (@_cursor)
    _drawCursor: =>
      canvas = @$el.find('.hover')[0]
      canvas.width = canvas.width
      return unless @_cursor
      @options.renderer.drawTile canvas.getContext('2d'), @_cursor, @options.colors.hover

    # **private**
    # Allows to zoom in and out the map
    # 
    # @param zoom [Number] the new zoom value.
    # @param noEvent [Boolean] do not change rendering, used when setting zoom programmatically.
    _zoom: (zoom, noEvent) =>
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
        o.renderer.init @

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
        @$el.trigger 'zoomChanged' unless noEvent
        # and reload coordinages
        @_zoomTimer = _.delay =>
          # compute new lowerCoord
          @setOption 'lowerCoord', @options.lowerCoord
        , 300

    # **private**
    # Image loading end handler. Draws it on the field layer, and if it's the last awaited image, 
    # remove field clone layer.
    #
    # @param success [Boolean] true if image was successfully loaded
    # @param src [String] the loaded image url
    # @param img [Image] an Image object, null in case of failure
    _onImageLoaded: (success, src, img) => 
      o = @options
      # do nothing if loading failed.
      return unless src in @_loadedImages
      @_loadedImages.splice @_loadedImages.indexOf(src), 1
      src = src.slice src.lastIndexOf('/')+1
      @_pendingImages--
        
      return @_replaceFieldClone() unless success
        
      ctx = @$el.find('.fields')[0].getContext '2d'
      # write on field layer, unless a clone layer exists
      ctx = @_cloneLayer[0].getContext '2d' if @_cloneLayer?

      # looks for data corresponding to this image
      for data in @_data
        if "#{data.typeId}-#{data.num}.png" is src
          {left, top} = o.renderer.coordToPos data
          ctx.drawImage img, left, top, o.renderer.tileW+1, o.renderer.tileH+1
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
    _onDrop: (event, details) =>
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
      @$el.trigger 'affect',
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
    _onDragStart: (event) =>
      o = @options
      # computes the absolute position and dimension of the widget
      offset = @$el.offset()
      @_dim = $.extend {}, offset
      @_dim.right = @_dim.left + o.renderer.width
      @_dim.bottom = @_dim.top + o.renderer.height

      cancel = false
      # keeps the start coordinate for a selection
      if event.shiftKey and @_selectable
        @_offset = offset
        @_start = o.renderer.posToCoord
          left: event.pageX+o.renderer.width-@_offset.left
          top: event.pageY+o.renderer.height-@_offset.top
        # adds a layer to draw selection
        @_selectLayer = @$el.find('.selection').clone()
        @_container.append @_selectLayer
        $(document).mousemove @_onDrag
        $(document).mouseup @_onSelectionEnd
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
    _onDrag: (event) =>
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
          left: event.pageX+o.renderer.width-@_offset.left
          top: event.pageY+o.renderer.height-@_offset.top
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
    _onDragStop: (event, details) =>
      delete this.options._dim
      if event.shiftKey and @_selectable
        # selection end
        @_onSelectionEnd event
      else
        # move end
        o = @options
        
        # get the movement's width and height
        reference = o.renderer.posToCoord left:o.renderer.width, top:o.renderer.height
        pos = 
          left:-parseInt @_container.css 'left'
          top:-parseInt @_container.css 'top'
        move = o.renderer.posToCoord pos
        move.x -= reference.x
        move.y -= reference.y

        # update widget coordinates
        o.lowerCoord.x += move.x
        o.lowerCoord.y += move.y
        o.renderer.init @

        # redraws everything
        @_drawGrid()
        @_drawMarkers()
        @_drawSelection()
        @_drawCursor()
        
        # place the container to only animate along a single tile dimension and run the end animation
        @_container.find('.movable').css o.renderer.replaceMovable move
        @_container.css o.renderer.replaceContainer pos
        @_container.transition
          left: -o.renderer.width
          top: -o.renderer.height
        , 200, =>
          # reloads map
          console.log "map move ends on x:#{o.lowerCoord.x} y:#{o.lowerCoord.y}"
          @setOption 'lowerCoord', o.lowerCoord

    # **private**
    # Drag'n drop selection end handler.
    # Adds all selected tiles to current selection and redraws it
    # @param event [Event] drag'n drop selection end event
    _onSelectionEnd: (event) =>
      o = @options
      # unbinds temporary handlers
      $(document).unbind 'mousemove', @_onDrag
      $(document).unbind 'mouseup', @_onSelectionEnd
      return unless @_start

      # removes temporary layer
      @_selectLayer.remove()
      # compute end coordinate
      end = o.renderer.posToCoord 
        left: event.pageX+o.renderer.width-@_offset.left
        top: event.pageY+o.renderer.height-@_offset.top
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
      @$el.trigger 'selectionChanged'

    # **private**
    # Click handler that toggle the clicked tile from selection if the ctrl key is pressed
    # @param event [Event] click event
    _onClick: (event) =>
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
      @$el.trigger 'selectionChanged'

  # widget declaration
  AuthoringMap._declareWidget 'authoringMap', 

    # delegate object used to draw tiles on map
    renderer: null

    # map id, to ignore items and fields that do not belongs to the displayed map
    mapId: null

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

  # The map renderer is used to render tiles on the map
  # Extending this class allows to have different tiles type: hexagonal, diamond...
  class MapRenderer

    # associated map widget
    map: null

    # map coordinate of the lower-left hidden corner
    origin: {x:0, y:0}

    # Map displayed width, without zoom taken in account
    width: null

    # Map displayed height, without zoom taken in account
    height: null

    # Individual tile width, taking zoom into account
    tileW: null

    # Individual tile height, taking zoom into account
    tileH: null
    
    # **private**
    # Returns the number of tile within the map total height.
    # Used to reverse the ordinate axis.
    #
    # @return number of tile in total map height
    _verticalTotalNum: () -> 
      (-1 + Math.floor @height*3/@tileH)*3

    # Initiate the renderer with map inner state. 
    # Initiate `tileW` and `tileH`.
    #
    # @param map [Object] the associated map widget
    # 
    init: (map) => throw new Error 'the `init` method must be implemented'

    # Compute the map coordinates of the other corner of displayed rectangle
    #
    # @param coord [Object] map coordinates of the upper/lower corner used as reference
    # @param upper [Boolean] indicate the the reference coordinate are the upper-right corner. 
    # False to indicate its the bottom-left corner
    # @return map coordinates of the other corner
    nextCorner: (coord, upper=true) => throw new Error 'the `nextCorner` method must be implemented'

    # Translate map coordinates to css position (relative to the map origin)
    #
    # @param coord [Object] object containing x and y coordinates
    # @option coord x [Number] object abscissa
    # @option coord y [Number] object ordinates
    # @return an object containing:
    # @option return left [Number] the object's left offset, relative to the map origin
    # @option return top [Number] the object's top offset, relative to the map origin
    coordToPos: (coord) => throw new Error 'the `coordToPos` method must be implemented'

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
    drawTile: (ctx, pos, color) => throw new Error 'the `drawTile` method must be implemented'

    # Place the movable layers after a move
    #
    # @param move [Object] map coordinates (x and y) of the movement
    # @return screen offset (left and top) of the movable layers
    replaceMovable: (move) => throw new Error 'the `replaceMovable` method must be implemented'
      
    # Place the container itself after a move.
    #
    # @param pos [Object] current screen position (left and top) of the container
    # @return screen offset (left and top) of the container
    replaceContainer: (pos) => throw new Error 'the `replaceContainer` method must be implemented'

  return {
    Widget: AuthoringMap
    Renderer: MapRenderer
  }