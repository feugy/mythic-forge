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
  'jquery'
  'underscore'
  'i18n!nls/widget'
  'widget/BaseWidget'
  'mousewheel'
],  ($, _, i18n) ->

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
    # second the straight equation: y = coeff*x+h
    h = a.y - coef*a.x
    # above if c.y is greater than the equation computation
    c.y > coef*c.x+h

  # Base widget for maps that allows drag'n drop affectation and selections
  AuthoringMap =

    options:   

      # Map kinds
      # Read-only, use `setOption('kind', ...)` to modify.
      kind: 'hexagon'

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

      # uppderCoord of the displayed map, without any zoom
      upperCoord: {x:0, y:0}

      # **private**
      # Coordinate of the hidden top left tile, origin of the map.
      _topLeft: {x:0, y:0}

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
      # Widget's dimension while drag'n drop operation.
      _dim: null

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
    # Build rendering
    _create: () ->
      @element.empty().removeClass().addClass("map-widget #{@options.kind}")
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
      ).click((event) =>
        mouse =
          x: if $.browser.webkit then event.offsetX else event.originalEvent.layerX
          y: if $.browser.webkit then event.offsetY else event.originalEvent.layerY
        console.log mouse
        console.log @_getCoord(mouse)
      ).appendTo(@element).bind('mousemove', (event) => 
        @_onHover(event)
      )

      # creates the field canvas element      
      $("""<canvas class="fields" height="#{o._height}" width="#{o._width}"></canvas>""").css(
        top: o._height
        left: o._width
      ).droppable(
        scope: o.dndType
        out: (event) => @_onOut(event)
        drop: (event) => @_onDrop(event)
      ).appendTo(o._container)

      # creates the grid canvas element      
      $("""<canvas class="grid" height="#{o._height*3}" width="#{o._width*3}"></canvas>""").appendTo(o._container)
      $("""<canvas class="markers" height="#{o._height*3}" width="#{o._width*3}"></canvas>""").appendTo(o._container)
      $("""<canvas class="selection" height="#{o._height*3}" width="#{o._width*3}"></canvas>""").appendTo(o._container)
      $("""<canvas class="hover" height="#{o._height*3}" width="#{o._width*3}"></canvas>""").appendTo(o._container)

      @_drawGrid()
      @_drawMarkers()
  
      # gets first data
      # TODO @setOption('topLeft', o._topLeft);

    
    # **private**
    # Method invoked when the widget options are set. Update rendering if `current` or `images` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.Widget.prototype._setOption.apply @, arguments unless key in ['kind', 'displayGrid', 'displayMarkers']
      switch key
        when 'kind'
          @options[key] = value
          @_create()
        when 'displayGrid'
          @options[key] = value
          @_drawGrid()
        when 'displayMarkers'
          @options[key] = value
          @_drawMarkers()

    # **private**
    # Allows sub-classes to compute individual tiles and map dimensions, without using zoom.
    # Must set attributes `_tileW`, `_tileH`, `_width`, `_height` and `_topLeft`
    _computeDimensions: () ->
      # horizontal hexagons: side length of an hexagon.
      s = @options.tileDim/2

      # dimensions of the square that embed an hexagon.
      # the angle used reflect the perspective effect. 60° > view from above. 45° > isometric perspective
      @options._tileH = s*Math.sin(45*Math.PI/180)*2
      @options._tileW = s*2

      # canvas dimensions (add 1 to take in account stroke width)
      @options._width = 1+(@options.horizontalTileNum*2+1)*s
      @options._height = 1+@options.verticalTileNum*0.75*@options._tileH+0.25*@options._tileH

      @options._topLeft = 
        x: @options.upperCoord.x - @options.horizontalTileNum
        y: @options.upperCoord.y - @options.verticalTileNum

    # **private**
    # Redraws the grid wireframe.
    _drawGrid: () ->
      canvas = @element.find('.grid')[0]
      ctx = canvas.getContext('2d')
      canvas.width = canvas.width
      o = @options
      return unless o.displayGrid

      ctx.strokeStyle = '#888'  
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
      ctx.fillStyle = '#f00'  # TODO couleur
      ctx.textAlign = 'center'
      ctx.textBaseline  = 'middle'
      originX = o._topLeft.x
      originY = o._topLeft.y
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
              ctx.fillText "#{gameX}:#{gameY+1}", x+o._tileW*((Math.abs(o._topLeft.y)+1) % 2), y+o._tileH*1.25

        line += 2

    # **private**
    # Draw a single selected tile in selection or to highlight hover
    # @param ctx [Canvas] the canvas context.
    # @param pos [Object] coordinate of the drew tile
    _drawTile: (ctx, pos) ->
      o = @options
      ctx.beginPath()
      coeff = Math.abs(pos.y+o._topLeft.y)%2
      shift = (Math.abs(pos.y)+1)%2 * Math.abs(o._topLeft.y%2)

      x = (pos.x-o._topLeft.x-shift) * o._tileW + coeff * 0.5 * o._tileW
      y = (pos.y-o._topLeft.y) * o._tileH * 0.75
      # draws an hexagon
      ctx.moveTo x+o._tileW*.5, y
      ctx.lineTo x, y+o._tileH*.25
      ctx.lineTo x, y+o._tileH*.75
      ctx.lineTo x+o._tileW*.5, y+o._tileH
      ctx.lineTo x+o._tileW, y+o._tileH*.75
      ctx.lineTo x+o._tileW, y+o._tileH*.25
      ctx.lineTo x+o._tileW*.5, y
      ctx.closePath()
      ctx.fillStyle = '#88A09D' # TODO couleur
      ctx.fill()

    # **private**
    # Draws the current selection on the selection layer
    _drawSelection: () ->
      o = @options
      return unless o._selectLayer
      console.log('redraws map selection');
      # clear selection
      canvas = o._selectLayer[0]
      ctx = canvas.getContext('2d')
      canvas.width = canvas.width
      o = @options
      ctx.fillStyle = 'rgb(120, 120, 120)' # TODO couleur
      for selected in o.selection
        @_drawTile(ctx, selected)

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

        # empty field canvas and reset it.
        #o._fields.attr('width', o.width);
        #var tmp = o.data;
        #o.data = [];
        #this.addData(tmp);
        # redraws everything
        @_drawGrid()
        @_drawMarkers()
        @_drawSelection()
        # trigger event
        @_trigger('zoomChanged') unless noEvent
        # and reload coordinages
        o._zoomTimer = setTimeout(() =>
          # todo
          return null
        , 500)

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
      row = Math.floor(mouse.y/(o._tileH*0.75))
      if row % 2 isnt 0
        mouse.x -= o._tileW*0.5
      col = Math.floor(mouse.x/o._tileW)

      # need to get in a plan here upper means greater y.
      mouse.y = o._height-mouse.y
      # upper summit of the hexagon
      a = 
        x: (col+0.5)*o._tileW
        y: o._height-row*o._tileH*0.75
      # top-right summit of the hexagon
      b = 
        x: (col+1)*o._tileW
        y: o._height-(row+0.25)*o._tileH*0.75
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
      y = o._topLeft.y+row
      pos = {
        x: col+o._topLeft.x+((y+1)%2)*Math.abs(o._topLeft.y%2)
        y: y
      }
      console.log pos
      return pos

    # **private**
    # Hover handler while dragging. Highlight the hovered tile.
    #
    # @param event [Event] mouse move event
    _onHover: (event) ->
      return unless @options._moveJumper++ % 3 is 0
      mouse =
        x: if $.browser.webkit then event.offsetX else event.originalEvent.layerX
        y: if $.browser.webkit then event.offsetY else event.originalEvent.layerY
      @options._cursor = @_getCoord(mouse);
      # displays hover indicator
      canvas = @element.find('.hover')[0]
      canvas.width = @options._width*3
      @_drawTile(canvas.getContext('2d'), @options._cursor)
    
    # **private**
    # Map drop handler. Triggers affectation.
    #
    # @param event [Event] move/selection end event.
    # @param details [Object] moved object details:
    # @option details draggable [Object] operation source
    # @option details helper [Object] moved object
    # @option details position [Object] current position of the moved object
    _dropHandler: (event, details) ->
      o = this.options;
      # mouse tracking ends.
      ###@_onLeave()
      // Coordonnées de laché, et information sur l'image.
      var coord = this._getCoord(event);
      var dragged = details.helper;
      var idx = dragged.data('idx');
      var uid = dragged.data('uid');
      console.debug('[_dropHandler] Drop de l\'image '+ idx +' du terrain '+
          uid + ' sur la carte à x:' + coord.x + ' y:' + coord.y);
      // Si le drop est en dehors de la séléction
      var inSelection = false;
      for(var i = 0; !inSelection && i < o.selection.length; i++) {
        inSelection = o.selection[i].x == coord.x && o.selection[i].y == 
          coord.y;
      }
      // Déclenche l'évènement d'affectation.
      this._trigger('affect', event, {
          typeUid: uid, 
          imageNum: idx,
          coord: coord,
          // Si on lâche dans de la séléction et qu'elle est multiple
          multiple: inSelection && o.selection.length > 1
        });###
    
    # **private**
    # Drag'n drop start handler. Keep the widget dimensions, and the start tile for selections.
    # It cancels the jQuery drag'n drop operation if it's a selection, and handle it manually.
    #
    # @param event [Event] drag'n drop start mouse event
    # @return false to cancel the jQuery drag'n drop operation
    _onDragStart: (event) ->
      o = @options
      # computes the absolute position and dimension of the widget
      widget = @element.offset()
      widget.right = widget.left + o._width
      widget.bottom = widget.top + o._height
      o._dim = widget

      cancel = false
      # keeps the start coordinate for a selection
      if event.shiftKey
        mouse =
          x: if $.browser.webkit then event.offsetX else event.originalEvent.layerX
          y: if $.browser.webkit then event.offsetY else event.originalEvent.layerY
        o._start = @_getCoord(mouse)
        # adds a layer to draw selection
        o._selectLayer = @element.find('.selection').clone()
        o._container.append(o._selectLayer)
        $(document).mousemove((event) => @_onDrag(event))
        $(document).mouseup((event) => @_onSelectionEnd(event))
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

      # TODO draws selection
      ### if o._start
      Evalue la fin temporaire de la séléction
      var end = this._getCoord(event)
      var lowerX = Math.min(end.x, o._start.x)
      var lowerY = Math.min(end.y, o._start.y)-1
      var higherX = Math.max(end.x, o._start.x)+1
      var higherY = Math.max(end.y, o._start.y)
      // Dessine un rectangle
      o._selectDrag.attr('width', o.tileNumWidth*o.tileWidth)
      var context = o._selectDrag[0].getContext('2d')
      context.strokeStyle = 'red'
      // coin supérieur gauche
      context.moveTo(o._actualTileWidth * (lowerX-o.upperCoord.x),
          o._actualTileHeight * (o.upperCoord.y-lowerY))
      // coin supérieur droit
      context.lineTo(o._actualTileWidth * (higherX-o.upperCoord.x),
          o._actualTileHeight * (o.upperCoord.y-lowerY))
      // coin inférieur droit
      context.lineTo(o._actualTileWidth * (higherX-o.upperCoord.x),
          o._actualTileHeight * (o.upperCoord.y-higherY))
      // coin inférieur gauche
      context.lineTo(o._actualTileWidth * (lowerX-o.upperCoord.x),
          o._actualTileHeight * (o.upperCoord.y-higherY))
      // coin supérieur gauche
      context.lineTo(o._actualTileWidth * (lowerX-o.upperCoord.x),
          o._actualTileHeight * (o.upperCoord.y-lowerY))
      context.stroke()###
    
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
        # @_onSelectionEnd(event, details)
      else
        # move end
        o = @options
        
        moveX = -parseInt(o._container.css('left'))
        moveY = -parseInt(o._container.css('top'))
        # update widget coordinates
        origin = @_getCoord({x:o._width, y:o._height})
        newPos =  @_getCoord({x:moveX, y:moveY})
        o._topLeft.x += newPos.x-origin.x
        o._topLeft.y += newPos.y-origin.y
        console.log('map move ends on x:'+o._topLeft.x+' y:'+o._topLeft.y)

        # and redraws everything, because it depends on the graduations
        @_drawGrid()
        @_drawMarkers()
        @_drawSelection()
        # displays hover indicator
        canvas = @element.find('.hover')[0]
        canvas.width = canvas.width
        @_drawTile(canvas.getContext('2d'), @options._cursor)

        # we need to ajust the end animation regarding the mouse position:
        # if it's over an half tile, follow the movement, otherwise, goes backward 
        shiftX = moveX % o._tileW
        if Math.abs(shiftX) >  o._tileW/2
          shiftX += (if shiftX > 0 then -1 else 1 ) * o._tileW

        shiftY = moveY % o._tileH*0.75 # TODO specific iso
        if Math.abs(shiftY) >  o._tileH*0.75/2
          shiftY += (if shiftY > 0 then -1 else 1 ) * o._tileH*0.75

        # place the container, and run the end animation
        o._container.css('left', -o._width+shiftX)
        o._container.css('top', -o._height+shiftY)
        o._container.transition(
          left: -o._width
          top: -o._height
        , 500)


        ### we need to stops on the nearest graduation by using modulo
        modX = currentX % o._tileW
        roundX = Math.round((currentX+o._width) / o._tileW)
        x = -Math.round(roundX + if modX-roundX < o._tileW / 2 then 0 else 1)
        modY = currentY % o._tileH*0.75
        roundY = Math.round((currentY+o._height) / o._tileH*0.75)
        y = Math.round(roundY + if modY-roundY < o._tileH*0.75 / 2 then 0 else 1)###

        # move the container, and invert its position to avoid a "go back" effect.
        ###posX = -offsetX + modX
        if roundX - modX > o._tileW / 2
          posX += o._tileW
        posY = -offsetY + modY
        if roundY - modY > o._tileH / 2
          posY += o._tileH

        o._container.css('left', posX)
        o._container.css('top', posY)
        o._container.animate(
          left: -offsetX,
          top: -offsetY,
          duration: 50
        )###

        ### Fait un clone du canvas des terrains pour éviter le 'flickering'
        clone = o._fields.clone()
        clone.addClass('clone')
        context = o._fields[0].getContext('2d')
        cloneContext = clone[0].getContext('2d')
        cloneContext.putImageData(
            context.getImageData(0, 0, offsetX, offsetY), 0, 0)
        # Le clone est décalé du déplacement.
        clone.css('left', -x*o._actualTileWidth+offsetX)
        clone.css('top', y*o._actualTileHeight+offsetY)

        o._fields.after(clone)
        # Vide le canvas de la grille.
        o._fields.attr('width', o.tileWidth*o.tileNumWidth)###

  $.widget('rheia.authoringMap', $.rheia.baseWidget, AuthoringMap)
