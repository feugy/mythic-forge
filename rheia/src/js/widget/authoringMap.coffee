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
  'widget/BaseWidget'
  'mousewheel'
],  ($, _) ->

  # Compute the location of the point C regarding the straight between A and B
  #
  # @param c [Object] tested point
  # @option c x [Number] C's abscissa
  # @option c y [Number] C's ordinate
  # @param a [Object] first reference point
  # @option a x [Number] A's abscissa
  # @option a y [Number] A's ordinate
  # @param b [Object] second reference point
  # @option b x [Number] B's abscissa
  # @option b y [Number] B's ordinate
  # @return true if C is above the straight formed by A and B
  _isAbove= (c, a, b) ->
    # first the leading coefficient
    coef = (b.y-a.y) / (b.x-a.x)
    # second the straight equation: y = coeff*x-h (because y is inverted)
    h = coef*a.x - a.y
    # above if c.y is greater than the equation computation
    c.y < coef*c.x-h

  # Extracts mouse position from DOM event, regarding the browser.
  # @param event [Event] 
  # @return the mouse position
  # @option return x the abscissa position
  # @option return y the ordinate position
  _mousePos= (event) ->
    return {
      x: if $.browser.webkit then event.offsetX else event.originalEvent.layerX
      y: if $.browser.webkit then event.offsetY else event.originalEvent.layerY
    }

  # Base widget for maps that allows drag'n drop affectation and selections
  AuthoringMap =

    options:   

      # displayed map content. 
      # Read-only, use `addData()` and `removeData()` to update.
      data: []

      # lower coordinates of the displayed map. Modification triggers the 'coordChanged' event, and reset map content.
      # Read-only, use `setOption('lowerCoord', ...)` to modify.
      lowerCoord: {x:0, y:0}

      # upper coordinates of the displayed map. Automatically updates when upper coordinates changes.
      # Read-only, do not modify manually.
      upperCoord: {x:0, y:0}

      # Awaited with and height for individual tiles, with normal zoom.
      # Read-only, use `setOption('tileWidth', ...)` to modify.
      tileDim: 100

      # Number of vertical displayed tiles 
      # Read-only, use `setOption('verticalTileNum', ...)` to modify.
      verticalTileNum: 10

      # Number of horizontal displayed tiles.
      # Read-only, use `setOption('horizontalTileNum', ...)` to modify.
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

      # **private**
      # color used for markers, grid, and so on.
      colors:
        selection: '#666'
        markers: 'red'
        grid: '#888'
        hover: '#ccc'

      # **private**
      # Coordinate of the hidden top left tile, origin of the map.
      _origin: {x:0, y:0}

      # **private**
      # Real tile width in pixel, taking zoom in account.
      _tileW: 0

      # **private**
      # Real tile height in pixel, taking zoom in account.
      _tileH: 0

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
  
    # Adds field to map. Will be effective only if the field is inside displayed bounds.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param added [Array<Object>] added data (JSON array). 
    addData: (added) ->
      o = @options
      for data in added
        if data.x >= o.lowerCoord.x and data.x <= o.upperCoord.x and data.y >= o.lowerCoord.y and data.y <= o.upperCoord.y
          o.data.push(data)
          img = "/images/#{data.typeId}-#{data.num}.png"
          unless img in o._loadedImages
            o._loadedImages.push(img)
            o._pendingImages++
            # data is inside displayed bounds: loads it
            rheia.router.trigger('loadImage', img) 

    # Removes field from map. Will be effective only if the field was displayed.
    # Works only on arrays of json field, not on Backbone.models (to reduce memory usage)
    #
    # @param removed [Field] removed data (JSON array). 
    removeData: (removed) ->
      o = @options     
      ctx = @element.find('.fields')[0].getContext('2d')
      for data in removed
        if data.x >= o.lowerCoord.x and data.x <= o.upperCoord.x and data.y >= o.lowerCoord.y and data.y <= o.upperCoord.y
          # draw white tile at removed field coordinate
          @_drawTile(ctx, data, 'white')
          # removes from local cache
          for field, i in o.data when field._id is data._id
            o.data.splice(i, 1)
            break

    # **private**
    # Build rendering
    _create: () ->
      @element.empty().removeClass().addClass('map-widget')
      o = @options;

      # dimensions depends on the map kind.
      @_computeDimensions()

      @element.css(
        height: o._height
        width: o._width
      ).mousewheel((event, delta) => 
        @_zoom(@options.zoom + delta*@options._zoomStep);
        event?.preventDefault()
        return false
      )

      # creates the layer container, 3 times bigger to allow drag operations
      o._container = $('<div class="perspective"></div>').css(
        height: o._height*3
        width: o._width*3
        top: -o._height
        left: -o._width
      ).draggable(
        distance: 5
        helper: () => return @options._container
        start: (event) => @_onDragStart(event)
        drag: (event) => @_onDrag(event)
        stop: (event, details) => @_onDragStop(event, details)
      ).on('click', (event) =>
        @_onClick(event)
      ).on('mousemove', (event) => 
        return unless @options._moveJumper++ % 3 is 0
        @options._cursor = @_getCoord(_mousePos(event));
        @_drawCursor()
      ).appendTo(@element)

      # creates the field canvas element      
      $("""<canvas class="fields" height="#{o._height*3}" width="#{o._width*3}"></canvas>""").droppable(
        scope: o.dndType
        drop: (event, details) => @_onDrop(event, details)
      ).appendTo(o._container)

      # creates the grid canvas element      
      $("""<canvas class="selection" height="#{o._height*3}" width="#{o._width*3}"></canvas>""").appendTo(o._container)
      $("""<canvas class="grid" height="#{o._height*3}" width="#{o._width*3}"></canvas>""").appendTo(o._container)
      $("""<canvas class="markers" height="#{o._height*3}" width="#{o._width*3}"></canvas>""").appendTo(o._container)
      $("""<canvas class="hover" height="#{o._height*3}" width="#{o._width*3}"></canvas>""").appendTo(o._container)

      @_drawGrid()
      @_drawMarkers()

      # image loading loading handler
      rheia.router.on('imageLoaded', (success, src, data) =>
        @_onImageLoaded(success, src, data)
      )
  
      # gets first data
      setTimeout(() =>
        @setOption('lowerCoord', o.lowerCoord)
      , 0)

    
    # **private**
    # Method invoked when the widget options are set. Update rendering if `current` or `images` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.Widget.prototype._setOption.apply @, arguments unless key in ['lowerCoord', 'displayGrid', 'displayMarkers']
      switch key
        when 'lowerCoord'
          @options[key] = value
          o = @options
          # computes lower coordinates
          o.upperCoord = 
            x: value.x+Math.round(o._width/o._tileW)
            y: value.y+Math.round(o._height/(o._tileH*0.75)) # TODO specific iso
          # creates a clone layer while reloading
          o._cloneLayer = $("<canvas width=\"#{o._width*3}\" height=\"#{o._height*3}\"></canvas>")
          @_trigger('coordChanged')
        when 'displayGrid'
          @options[key] = value
          @_drawGrid()
        when 'displayMarkers'
          @options[key] = value
          @_drawMarkers()

    # **private**
    # If no image loading remains, and if a clone layer exists, then its content is 
    # copied into the field layer
    _replaceFieldClone: () ->
      o = @options
      # only if no image loading is pendinf
      return unless o._pendingImages is 0 and o._cloneLayer?
      # all images were rendered on clone layer: copy it on field layer.
      fieldLayer = o._container.find('.fields')
      fieldLayer.css({top:0, left:0})
      canvas = fieldLayer[0]
      canvas.width = canvas.width
      canvas.getContext('2d').putImageData(o._cloneLayer[0].getContext('2d').getImageData(0, 0, o._width*3, o._height*3), 0, 0)
      o._cloneLayer.remove()
      o._cloneLayer = null

    # **private**
    # Allows sub-classes to compute individual tiles and map dimensions, without using zoom.
    # Must set attributes `_tileW`, `_tileH`, `_width`, `_height` and `_origin`
    _computeDimensions: () ->
      # horizontal hexagons: side length of an hexagon.
      s = @options.tileDim/2

      # dimensions of the square that embed an hexagon.
      # the angle used reflect the perspective effect. 60° > view from above. 45° > isometric perspective
      @options._tileH = s*Math.sin(45*Math.PI/180)*2
      @options._tileW = s*2

      # canvas dimensions (add 1 to take in account stroke width)
      @options._width = 1+(@options.horizontalTileNum*2+1)*s
      @options._height = 1+@options.verticalTileNum*0.75*@options._tileH+0.25*@options._tileH # TODO specific iso

      @options._origin = 
        x: @options.lowerCoord.x - @options.horizontalTileNum
        y: @options.lowerCoord.y - @options.verticalTileNum

    # **private**
    # Redraws the grid wireframe.
    _drawGrid: () ->
      canvas = @element.find('.grid')[0]
      ctx = canvas.getContext('2d')
      canvas.width = canvas.width
      o = @options
      return unless o.displayGrid

      ctx.strokeStyle = o.colors.grid 
      # draw grid on it
      for y in [0.5..o._height*3] by o._tileH*1.5
        for x in [0.5..o._width*3] by o._tileW    
          # horizontal hexagons
          # first hexagon: starts from top-right summit, and draws counter-clockwise until bottom summit
          ctx.moveTo(x+o._tileW, y+o._tileH*0.25)
          ctx.lineTo(x+o._tileW*0.5, y)
          ctx.lineTo(x, y+o._tileH*0.25)
          ctx.lineTo(x, y+o._tileH*0.75)
          ctx.lineTo(x+o._tileW*0.5, y+o._tileH)
          # second hexagon: starts from top summit, and draws counter-clockwise until bottom-right summit
          ctx.moveTo(x+o._tileW, y+o._tileH*0.75)
          ctx.lineTo(x+o._tileW*0.5, y+o._tileH)
          ctx.lineTo(x+o._tileW*0.5, y+o._tileH*1.5)
          ctx.lineTo(x+o._tileW, y+o._tileH*1.75)
          ctx.lineTo(x+o._tileW*1.5, y+o._tileH*1.5)
      ctx.stroke()

    # **private**
    # Redraws the grid markers.
    _drawMarkers: () ->
      canvas = @element.find('.markers')[0]
      ctx = canvas.getContext('2d')
      canvas.width = canvas.width
      o = @options
      return unless o.displayMarkers

      ctx.font = "#{15*o.zoom}px sans-serif"
      ctx.fillStyle = o.colors.markers
      ctx.textAlign = 'center'
      ctx.textBaseline  = 'middle'
      originX = o._origin.x
      originY = o._origin.y
      # draw grid on it
      line = 0
      for y in [0.5..o._height*3] by o._tileH*1.5
        for x in [0.5..o._width*3] by o._tileW   
          gameX = originX + Math.floor(x/o._tileW)
          gameY = originY + line

          if gameX % 5 is 0
            if gameY % 5 is 0
              ctx.fillText "#{gameX}:#{gameY}", x+o._tileW*0.5, y+o._tileH*0.5
            else if gameY > 0 and gameY % 5 is 4 or gameY < 0 and gameY % 5 is -1
              ctx.fillText "#{gameX}:#{gameY+1}", x+o._tileW*((Math.abs(o._origin.y)+1) % 2), y+o._tileH*1.25

        line += 2

    # **private**
    # Draw a single selected tile in selection or to highlight hover
    # @param ctx [Canvas] the canvas context.
    # @param pos [Object] coordinate of the drew tile
    # @param color [String] the color used to fill the tile
    _drawTile: (ctx, pos, color) ->
      o = @options
      ctx.beginPath()
      coeff = Math.abs(pos.y+o._origin.y)%2
      shift = (Math.abs(pos.y)+1)%2 * Math.abs(o._origin.y%2)

      x = (pos.x-o._origin.x-shift) * o._tileW + coeff * 0.5 * o._tileW
      y = (pos.y-o._origin.y) * o._tileH * 0.75 # TODO specific iso
      # draws an hexagon
      ctx.moveTo x+o._tileW*.5, y
      ctx.lineTo x, y+o._tileH*.25
      ctx.lineTo x, y+o._tileH*.75
      ctx.lineTo x+o._tileW*.5, y+o._tileH
      ctx.lineTo x+o._tileW, y+o._tileH*.75
      ctx.lineTo x+o._tileW, y+o._tileH*.25
      ctx.lineTo x+o._tileW*.5, y
      ctx.closePath()
      ctx.fillStyle = color
      ctx.fill()

    # **private**
    # Draws the current selection on the selection layer
    _drawSelection: () ->
      o = @options
      console.log('redraws map selection');
      # clear selection
      canvas = @element.find('.selection')[0]
      ctx = canvas.getContext('2d')
      canvas.width = canvas.width
      o = @options
      ctx.fillStyle = o.colors.selection
      for selected in o.selection
        @_drawTile(ctx, selected, @options.colors.selection)

    # **private**
    # Redraws cursor on stored position (@options._cursor)
    _drawCursor: () ->
      return unless @options._cursor
      canvas = @element.find('.hover')[0]
      canvas.width = canvas.width
      @_drawTile(canvas.getContext('2d'), @options._cursor, @options.colors.hover)

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
      if zoom > 1-o._zoomStep and zoom < 1+o._zoomStep
        zoom = 1
      
      # stay within allowed bounds
      if zoom < 1
        zoom = Math.max(zoom, o.minZoom)
      else
        zoom = Math.min(zoom, o.maxZoom)
      
      console.log("new map zoom: #{zoom}")
      if noEvent or zoom != o.zoom
        # stop running timer
        if o._zoomTimer
          clearTimeout(o._zoomTimer)
        
        o.zoom = zoom
        # computes again current dimensions
        @_computeDimensions()
        o._tileW *= o.zoom
        o._tileH *= o.zoom

        # redraws everything
        @_drawGrid()
        @_drawMarkers()
        @_drawSelection()
        @_drawCursor()

        # redraws totally the field layer
        canvas = o._container.find('.fields')[0]
        canvas.width = canvas.width
        tmp = o.data
        o.data = []
        @addData(tmp)

        # trigger event
        @_trigger('zoomChanged') unless noEvent
        # and reload coordinages
        o._zoomTimer = setTimeout(() =>
          # compute new lowerCoord
          o = @options
          newCoord =
            x: o._origin.x+Math.round(o._width/o._tileW)-1
            y: o._origin.y+Math.round(o._height/(o._tileH*0.75)) # TODO specific iso
          console.log('map zoom ends on x:'+newCoord.x+' y:'+newCoord.y)
          @setOption('lowerCoord', newCoord)
        , 300)

    # **private**
    # Returns coordinates of the hovered tile
    #  
    # @param mouse [Object] mouse position relatively to the container
    # @option result x [Number] pixel horizontal position
    # @option result y [Number] pixel vertical position
    # @return coordinates
    # @option result x [Number] tile abscissa
    # @option result y [Number] tile ordinates
    _getCoord: (mouse) ->
      o = @options
      # locate the upper rectangle in which the mouse hit
      row = Math.floor(mouse.y/(o._tileH*0.75)) # TODO specific iso
      if row % 2 isnt 0
        mouse.x -= o._tileW*0.5
      col = Math.floor(mouse.x/o._tileW)

      # upper summit of the hexagon
      a = 
        x: (col+0.5)*o._tileW
        y: row*o._tileH*0.75
      # top-right summit of the hexagon
      b = 
        x: (col+1)*o._tileW
        y: (row+0.25)*o._tileH*0.75
      # top-left summit of the hexagon
      c = 
        x: col*o._tileW
        y: b.y
      # if the hit fell in the upper right triangle, it's in the hexagon above and right
      if _isAbove(mouse, a, b)
        col++ if row % 2
        row--
      # or if the hit fell in the upper left triangle, it's in the hexagon above and left
      else if _isAbove(mouse, c, a)
        col-- unless row % 2
        row--
      # or it's the good hexagon :)
      y = o._origin.y+row
      pos = {
        x: col+o._origin.x+Math.abs(o._origin.y%2)*(Math.abs(y)+1)%2
        y: y
      }
      return pos

    # **private**
    # Image loading end handler. Draws it on the field layer, and if it's the last awaited image, 
    # remove field clone layer.
    #
    # @param success [Boolean] true if image was successfully loaded
    # @param src [String] the loaded image url
    # @param img [Image] an Image object, null in case of failure
    # @param data [String] the image base 64 encoded string, null in case of failure
    _onImageLoaded: (success, src, img, data) -> 
      o = @options
      # do nothing if loading failed.
      return unless src in o._loadedImages
      o._loadedImages.splice(o._loadedImages.indexOf(src), 1)
      src = src.slice(src.lastIndexOf('/')+1)
      o._pendingImages--
        
      return @_replaceFieldClone() unless success
        
      ctx = @element.find('.fields')[0].getContext('2d')
      # write on field layer, unless a clone layer exists
      ctx = o._cloneLayer[0].getContext('2d') if o._cloneLayer?

      # looks for data corresponding to this image
      for data in o.data
        if "#{data.typeId}-#{data.num}.png" is src
          # TODO specific iso
          coeff = Math.abs(data.y+o._origin.y)%2
          shift = (Math.abs(data.y)+1)%2 * Math.abs(o._origin.y%2)
          row = (data.y-o._origin.y) * o._tileH * 0.75
          col = (data.x-o._origin.x-shift) * o._tileW + coeff * 0.5 * o._tileW
          # TODO speicfic iso: there is a tiny shift: 0.25 vertical and 0.5 horizontal
          ctx.drawImage(img, col, row, o._tileW, o._tileH)
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
      o = this.options;
      return unless o._cursor
      # extract dragged datas
      idx = details.helper.data('idx')
      id = details.helper.data('id')
      console.log("drops images #{idx} of field #{id} at coordinates x:#{o._cursor.x}, y:#{o._cursor.y}")
      # indicates if it's in selection or not
      inSelection = false
      for selected in o.selection when selected.x is o._cursor.x and selected.y is o._cursor.y
        inSelection = true
        break
      # triggers affectation.
      @_trigger('affect', event,
        typeId: id
        num: idx,
        coord: o._cursor,
        inSelection: inSelection and o.selection.length isnt 0
      )
    
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
      o._dim = $.extend({}, offset)
      o._dim.right = o._dim.left + o._width
      o._dim.bottom = o._dim.top + o._height

      cancel = false
      # keeps the start coordinate for a selection
      if event.shiftKey
        o._offset = offset
        o._start = @_getCoord({x:event.pageX+o._width-o._offset.left, y:event.pageY+o._height-o._offset.top})
        # adds a layer to draw selection
        o._selectLayer = @element.find('.selection').clone()
        o._container.append(o._selectLayer)
        o._onDragTemp = (event) => @_onDrag(event)
        o._onSelectionEndTemp = (event) => @_onSelectionEnd(event)
        $(document).mousemove(o._onDragTemp)
        $(document).mouseup(o._onSelectionEndTemp)
        cancel = true

        # empties current selection
        if !event.ctrlKey
          o.selection = []
          @_drawSelection()
      
      return !cancel
    
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
      
      mouse = {left: event.pageX, top: event.pageY}
      if mouse.left < o._dim.left || mouse.left > o._dim.right || 
          mouse.top < o._dim.top || mouse.top > o._dim.bottom
        # we left the widget, stops the operation
        if o._start
          @_onSelectionEnd(event)
        return false

      # draws temporary selection
      if o._start and o._selectLayer
        # compute temporary end of the selectionEvalue la fin temporaire de la séléction
        end = @_getCoord({x:event.pageX+o._width-o._offset.left, y:event.pageY+o._height-o._offset.top})
        lower =
          x: Math.min(end.x, o._start.x)
          y: Math.min(end.y, o._start.y)
        higher =
          x: Math.max(end.x, o._start.x)
          y: Math.max(end.y, o._start.y)
        canvas = o._selectLayer[0]
        ctx = canvas.getContext('2d')
        canvas.width = canvas.width
        # walk through selected tiles
        for x in [lower.x..higher.x]
          for y in [lower.y..higher.y]
            @_drawTile(ctx, {x:x, y:y}, @options.colors.selection)
    
    # **private**
    # Drag'n drop handler that ends selection or move map.
    #
    # @param event [Event] move/selection end event.
    # @param details [Object] moved object details:
    # @option details draggable [Object] operation source
    # @option details helper [Object] moved object
    # @option details position [Object] current position of the moved object
    _onDragStop: (event, details) ->
      delete(this.options._dim)
      if event.shiftKey
        # selection end
        @_onSelectionEnd(event)
      else
        # move end
        o = @options
        
        moveX = -parseInt(o._container.css('left'))
        moveY = -parseInt(o._container.css('top'))

        # update widget coordinates
        origin = @_getCoord({x:o._width, y:o._height})
        newPos =  @_getCoord({x:moveX, y:moveY})
        o._origin.x += newPos.x-origin.x
        o._origin.y += newPos.y-origin.y

        # and redraws everything, because it depends on the graduations
        @_drawGrid()
        @_drawMarkers()
        @_drawSelection()
        @_drawCursor()

        # we need to ajust the end animation regarding the mouse position:
        # if it's over an half tile, follow the movement, otherwise, goes backward 
        shiftX = moveX % o._tileW
        if Math.abs(shiftX) >  o._tileW/2
          shiftX += (if shiftX > 0 then -1 else 1 ) * o._tileW

        shiftY = moveY % o._tileH*0.75 # TODO specific iso
        if Math.abs(shiftY) >  o._tileH*0.75/2
          shiftY += (if shiftY > 0 then -1 else 1 ) * o._tileH*0.75

        # place fields layer because it will be redrawn once all new content would have been retrieved 
        fShiftX = origin.x-newPos.x
        fShiftY = origin.y-newPos.y
        if fShiftY % 2 isnt 0
          fShiftX += if o._origin.y % 2 then -0.5 else 0.5
        o._container.find('.fields').css(
          left: fShiftX*o._tileW
          top: fShiftY*o._tileH*0.75
        )

        # place the container, and run the end animation
        o._container.css(
          left: -o._width+shiftX
          top: -o._height+shiftY
        )
        o._container.transition(
          left: -o._width
          top: -o._height
        , 500, () =>
          # reloads map
          newCoord =
            x: o._origin.x+Math.round(o._width/o._tileW)-1
            y: o._origin.y+Math.round(o._height/(o._tileH*0.75)) # TODO specific iso
          console.log('map move ends on x:'+newCoord.x+' y:'+newCoord.y)
          @setOption('lowerCoord', newCoord)
        )

    # **private**
    # Drag'n drop selection end handler.
    # Adds all selected tiles to current selection and redraws it
    # @param event [Event] drag'n drop selection end event
    _onSelectionEnd: (event) ->
      o = @options
      # unbinds temporary handlers
      $(document).unbind('mousemove', o._onDragTemp)
      $(document).unbind('mouseup', o._onSelectionEndTemp)
      return unless o._start

      # removes temporary layer
      o._selectLayer.remove();
      # compute end coordinate
      end = @_getCoord({x:event.pageX+o._width-o._offset.left, y:event.pageY+o._height-o._offset.top})
      console.log("selection between x:#{o._start.x} y:#{o._start.y} and x:#{end.x} y:#{end.y}")

      lower =
        x: Math.min(end.x, o._start.x)
        y: Math.min(end.y, o._start.y)
      higher =
        x: Math.max(end.x, o._start.x)
        y: Math.max(end.y, o._start.y)
      # walk through selected tiles
      for x in [lower.x..higher.x]
        for y in [lower.y..higher.y]
          found = false
          (found = true; break) for tile in o.selection when tile.x is x and tile.y is y
          o.selection.push({x:x, y:y}) unless found
      o._start = null;
      # redraw selection
      @_drawSelection()
      @_trigger('selectionChanged')

    # **private**
    # Click handler that toggle the clicked tile from selection if the ctrl key is pressed
    # @param event [Event] click event
    _onClick: (event) ->
      coord = @_getCoord(_mousePos(event))
      console.log("click on tile x:#{coord.x} y:#{coord.y} with control key #{event.ctrlKey}")
      add = true
      if event.ctrlKey
        # search in selection
        for tile, i in @options.selection when tile.x is coord.x and tile.y is coord.y
          add = false
          @options.selection.splice(i, 1)
          break
      else
        # empties selection
        @options.selection = []

      # selects the clicked tile and redraw
      @options.selection.push(coord) if add
      @_drawSelection()
      @_trigger('selectionChanged')


  $.widget('rheia.authoringMap', $.rheia.baseWidget, AuthoringMap)
