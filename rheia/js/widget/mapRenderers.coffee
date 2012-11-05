'use strict'

define [
  'widget/authoringMap'
],  (Renderer) ->


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
  _isBelow= (c, a, b) ->
    # first the leading coefficient
    coef = (b.y - a.y) / (b.x - a.x)
    # second the straight equation: y = coeff*x + h
    h = a.y - coef*a.x
    # below if c.y is higher than the equation computation (because y is inverted)
    c.y > coef*c.x + h

  {
    hexagon: class HexagonRenderer extends Renderer

      # Initiate the renderer with map inner state. 
      # Initiate `tileW` and `tileH`.
      #
      # @param map [Object] the associated map widget
      # 
      init: (map) =>
        @map = map
        # horizontal hexagons: side length of an hexagon.
        s = map.options.tileDim/2

        # dimensions of the square that embed an hexagon.
        # the angle used reflect the perspective effect. 60° > view from above. 45° > isometric perspective
        @tileRenderH = s*map.options.zoom*2*Math.sin map.options.angle*Math.PI/180
        @tileRenderW = s*map.options.zoom*2
        @tileH = @tileRenderH*0.75
        @tileW = @tileRenderW

      # Translate map coordinates to css position (relative to the map origin)
      #
      # @param coord [Object] object containing x and y coordinates
      # @option coord x [Number] object abscissa
      # @option coord y [Number] object ordinates
      # @return an object containing:
      # @option return left [Number] the object's left offset, relative to the map origin
      # @option return top [Number] the object's top offset, relative to the map origin
      # @option return z-index [Number] the object's z-index
      coordToPos: (obj) =>
        refs = @map.mapRefs()
        # invert y axis
        top = refs.height - ((obj.y - refs.origin.y + 1) + 0.25/0.75) * @tileH
        # shift to right on even rows
        shift = if Math.floor((refs.height-top)/@tileH)%2 then 0 else if Math.abs(refs.origin.y)%2  then -1 else 1
        {
          # left may be shifted on even rows
          left: (obj.x - refs.origin.x + 0.5*shift) * @tileW
          top: top
          # for z-index, row is more important than column
          'z-index': (refs.verticalTotalNum*3-obj.y+refs.origin.y)*2 + obj.x 
        }

      # Translate css position (relative to the map origin) to map coordinates to css position
      #
      # @param coord [Object] object containing top and left position relative to the map origin
      # @option coord left [Number] the object's left offset
      # @option coord top [Number] the object's top offset
      # @return an object containing:
      # @option return x [Number] object abscissa
      # @option return y [Number] object ordinates
      posToCoord: (pos) =>
        refs = @map.mapRefs()
        # locate the upper rectangle in which the mouse hit, with reverted y axis
        row = Math.floor (refs.height-pos.y)/@tileH
        shift = 0
        if row % 2 is 1
          shift = @tileW*0.5
        col = Math.floor (pos.x+shift)/@tileW
        
        # bottom summit of the hexagon
        a = 
          x: (col+0.5)*@tileW-shift
          y: refs.height-row*@tileH-2
        # bottom-right summit of the hexagon
        b = 
          x: (col+1)*@tileW-shift
          y: refs.height-(row+0.25)*@tileH-2
        # bottom-left summit of the hexagon
        c = 
          x: col*@tileW-shift
          y: b.y

        if _isBelow pos, c, a
          # if the hit fell in the lower left triangle, it's in the hexagon below and left
          col-- if row % 2 is 1
          row--
        else if _isBelow pos, a, b
          # or if the hit fell in the lower right triangle, it's in the hexagon below and right
          col++ if row % 2 is 0
          row--
        # or it's the good hexagon :)
        y = row+refs.origin.y
        {
          x: col+refs.origin.x-Math.abs(y)%2*(Math.abs(refs.origin.y)+1)%2
          y: y
        }


      # Draws the grid wireframe on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawGrid: (ctx) =>
        refs = @map.mapRefs()
        # draw grid on it, with revert ordinate axis
        step = -@tileRenderH*1.5
        for y in [refs.height-0.5..0.5] by step
          for x in [0.5..refs.width] by @tileRenderW    
            # horizontal hexagons
            # first hexagon: starts from bottom-right summit, and draws clockwise until top summit
            ctx.moveTo x+@tileRenderW, y-@tileRenderH*0.25
            ctx.lineTo x+@tileRenderW*0.5, y
            ctx.lineTo x, y-@tileRenderH*0.25
            ctx.lineTo x, y-@tileRenderH*0.75
            ctx.lineTo x+@tileRenderW*0.5, y-@tileRenderH
            # second hexagon: starts from bottom summit, and draws clockwise until top-right summit
            ctx.moveTo x+@tileRenderW, y-@tileRenderH*0.75
            ctx.lineTo x+@tileRenderW*0.5, y-@tileRenderH
            ctx.lineTo x+@tileRenderW*0.5, y-@tileRenderH*1.5
            ctx.lineTo x+@tileRenderW, y-@tileRenderH*1.75
            ctx.lineTo x+@tileRenderW*1.5, y-@tileRenderH*1.5
            
        ctx.stroke()

      # Draws the markers on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawMarkers: (ctx) =>
        refs = @map.mapRefs()
        # initialise a line number, starting from the bottom and going up
        step = -@tileRenderH*1.5
        line = originY = Math.floor (refs.height-@tileRenderH)/step
        for y in [refs.height-0.5..0.5] by step
          for x in [0.5..refs.width] by @tileRenderW    
            gameX = refs.origin.x + Math.floor x/@tileRenderW
            gameY = refs.origin.y + line - originY

            if gameX % 5 is 0
              if gameY % 5 is 0
                ctx.fillText "#{gameX}:#{gameY}", x+@tileRenderW*0.5, y-@tileRenderH*0.5
              else if gameY > 0 and gameY % 5 is 4 or gameY < 0 and gameY % 5 is -1
                ctx.fillText "#{gameX}:#{gameY+1}", x+@tileRenderW*((Math.abs(refs.origin.y)+1) % 2), y-@tileRenderH*1.25

          line += 2

      # Draw a single selected tile in selection or to highlight hover
      #
      # @param ctx [Canvas] the canvas context.
      # @param pos [Object] coordinate of the drew tile
      # @param color [String] the color used to fill the tile
      drawTile: (ctx, pos, color) ->
        ctx.beginPath()
        {left, top} = @coordToPos pos
        # draws an hexagon
        ctx.moveTo left+@tileRenderW*.5, top
        ctx.lineTo left, top+@tileRenderH*.25
        ctx.lineTo left, top+@tileRenderH*.75
        ctx.lineTo left+@tileRenderW*.5, top+@tileRenderH
        ctx.lineTo left+@tileRenderW, top+@tileRenderH*.75
        ctx.lineTo left+@tileRenderW, top+@tileRenderH*.25
        ctx.closePath()
        ctx.fillStyle = color
        ctx.fill()

    # Diamond renderer creates isometric maps.
    diamond: class DiamondRenderer extends Renderer

      # Initiate the renderer with map inner state. 
      # Initiate `tileW` and `tileH`.
      #
      # @param map [Object] the associated map widget
      # 
      init: (map) =>
        @map = map
        # dimensions of the square that embed an diamond.
        @tileRenderH = map.options.tileDim*map.options.zoom*Math.sin map.options.angle*Math.PI/180
        @tileRenderW = map.options.tileDim*map.options.zoom
        @tileH = @tileRenderH*0.5
        @tileW = @tileRenderW

      # Translate map coordinates to css position (relative to the map origin)
      #
      # @param coord [Object] object containing x and y coordinates
      # @option coord x [Number] object abscissa
      # @option coord y [Number] object ordinates
      # @return an object containing:
      # @option return left [Number] the object's left offset, relative to the map origin
      # @option return top [Number] the object's top offset, relative to the map origin
      # @option return z-index [Number] the object's z-index
      coordToPos: (obj) =>
        refs = @map.mapRefs()
        col = obj.x - refs.origin.x
        row = obj.y - refs.origin.y
        {
          left: (col+row)*@tileRenderW/2
          top: refs.height-(2-col+row)*@tileRenderH/2
          # for z-index, column is more important than row (which is inverted)
          'z-index': (refs.verticalTotalNum*3-obj.y+refs.origin.y) + obj.x*2 
        }

      # Translate css position (relative to the map origin) to map coordinates to css position
      #
      # @param coord [Object] object containing top and left position relative to the map origin
      # @option coord left [Number] the object's left offset
      # @option coord top [Number] the object's top offset
      # @return an object containing:
      # @option return x [Number] object abscissa
      # @option return y [Number] object ordinates
      posToCoord: (pos) =>
        refs = @map.mapRefs()
        # locate the upper rectangle in which the mouse hit, with reverted y axis
        row = Math.floor (refs.height-pos.y)/@tileH
        shift = 0
        xShift = 0
        if row % 2 is 1
          shift = @tileW*0.5
          xShift = -1
        col = Math.floor (pos.x+shift)/@tileW

        # bottom summit of the diamond
        a = 
          x: (col+0.5)*@tileW-shift
          y: refs.height-row*@tileH
        # right summit of the diamond
        b = 
          x: (col+1)*@tileW-shift
          y: refs.height-(row+1)*@tileH
        # left summit of the diamond
        c = 
          x: col*@tileW-shift
          y: b.y

        if _isBelow pos, c, a
          # if the hit fell in the lower left triangle, it's in the diamond below and left
          if row%2
            col--
            xShift = 0
          else
            xShift = -1
          row-- 
        else if _isBelow pos, a, b
          # or if the hit fell in the lower right triangle, it's in the diamond below and right
          if row%2
            xShift = 0
          else
            col++
            xShift = -1
          row--
        # or it's the good diamond

        row = Math.floor row/2
        {
          x: refs.origin.x - row + col + xShift
          y: refs.origin.y + row + col
        }

      # Draws the grid wireframe on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawGrid: (ctx) =>
        refs = @map.mapRefs()
        i = 0
        for y in [refs.height-0.5..0.5] by -@tileRenderH*0.5
          for x in [0.5..refs.width] by @tileRenderW
            # even rows are shifted by 1/2 width
            shift = if i%2 then @tileRenderW*0.5 else 0
            # draw a diamond counter-clockwise from top summit
            ctx.moveTo x+shift+@tileRenderW*0.5, y-@tileRenderH
            ctx.lineTo x+shift, y-@tileRenderH*0.5
            ctx.lineTo x+shift+@tileRenderW*0.5, y
            ctx.lineTo x+shift+@tileRenderW, y-@tileRenderH*0.5
            ctx.lineTo x+shift+@tileRenderW*0.5, y-@tileRenderH
          i++
        ctx.stroke()

      # Draws the markers on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawMarkers: (ctx) =>
        refs = @map.mapRefs()
        row = 0
        for y in [refs.height-0.5..0.5] by -@tileRenderH
          col = 0
          for x in [0.5..refs.width] by @tileRenderW    
            gameX = refs.origin.x - row + col
            gameY = refs.origin.y + row + col

            if gameX % 5 is 0
              if gameY % 5 is 0
                ctx.fillText "#{gameX}:#{gameY}", x+@tileRenderW*0.5, y-@tileRenderH*0.5
              else if gameY > 0 and gameY % 5 is 4 or gameY < 0 and gameY % 5 is -1
                ctx.fillText "#{gameX}:#{gameY+1}", x+@tileRenderW, y-@tileRenderH
            col++
          row++


      # Draw a single selected tile in selection or to highlight hover
      #
      # @param ctx [Canvas] the canvas context.
      # @param pos [Object] coordinate of the drew tile
      # @param color [String] the color used to fill the tile
      drawTile: (ctx, pos, color) ->
        ctx.beginPath()
        {left, top} = @coordToPos pos
        # draws a diamond
        ctx.moveTo left+@tileRenderW*.5, top
        ctx.lineTo left, top+@tileRenderH*.5
        ctx.lineTo left+@tileRenderW*.5, top+@tileRenderH
        ctx.lineTo left+@tileRenderW, top+@tileRenderH*0.5
        ctx.closePath()
        ctx.fillStyle = color
        ctx.fill()

    # Square renderer creates classic checkerboard maps
    square: class SquareRenderer extends Renderer

      # Initiate the renderer with map inner state.
      # Initiate `tileW`, `tileH`, `tileRenderW` and `tileRenderH`.
      #
      # @param map [Object] the associated map widget
      # 
      init: (map) =>
        @map = map
        # dimensions of the square.
        @tileRenderH = map.options.tileDim*map.options.zoom
        @tileRenderW = map.options.tileDim*map.options.zoom
        @tileH = @tileRenderH
        @tileW = @tileRenderW

      # Translate map coordinates to css position (relative to the map origin)
      #
      # @param coord [Object] object containing x and y coordinates
      # @option coord x [Number] object abscissa
      # @option coord y [Number] object ordinates
      # @return an object containing:
      # @option return left [Number] the object's left offset, relative to the map origin
      # @option return top [Number] the object's top offset, relative to the map origin
      # @option return z-index [Number] the object's z-index
      coordToPos: (obj) =>
        refs = @map.mapRefs()
        {
          left: (obj.x - refs.origin.x)*@tileW
          top: refs.height-(obj.y + 1 - refs.origin.y)*@tileH
          # for z-index, inverted rows is more important 
          'z-index': (refs.verticalTotalNum*3-obj.y+refs.origin.y)*2+obj.x 
        }

      # Translate css position (relative to the map origin) to map coordinates to css position
      #
      # @param coord [Object] object containing top and left position relative to the map origin
      # @option coord left [Number] the object's left offset
      # @option coord top [Number] the object's top offset
      # @return an object containing:
      # @option return x [Number] object abscissa
      # @option return y [Number] object ordinates
      posToCoord: (pos) =>
        refs = @map.mapRefs()
        {
          y: refs.origin.y + Math.floor (refs.height-pos.y)/@tileH
          x: refs.origin.x + Math.floor pos.x/@tileW
        }

      # Draws the grid wireframe on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawGrid: (ctx) =>
        refs = @map.mapRefs()
        i = 0
        # draws horizontal lines starting from bottom
        for y in [refs.height-0.5..0.5] by -@tileH
          ctx.moveTo 0, y
          ctx.lineTo refs.width, y

        # draws vertical lines
        for x in [0.5..refs.width] by @tileW
          ctx.moveTo x, 0
          ctx.lineTo x, refs.height
        ctx.stroke()

      # Draws the markers on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawMarkers: (ctx) =>
        refs = @map.mapRefs()
        row = 0
        for y in [refs.height-0.5..0.5] by -@tileH
          gameY = refs.origin.y + row++
          if gameY % 5 is 0
            col = 0
            for x in [0.5..refs.width] by @tileW    
              gameX = refs.origin.x + col++
              if gameX % 5 is 0
                ctx.fillText "#{gameX}:#{gameY}", x+@tileW*0.5, y-@tileH*0.5

      # Draw a single selected tile in selection or to highlight hover
      #
      # @param ctx [Canvas] the canvas context.
      # @param pos [Object] coordinate of the drew tile
      # @param color [String] the color used to fill the tile
      drawTile: (ctx, pos, color) ->
        ctx.beginPath()
        {left, top} = @coordToPos pos
        # draws a square
        ctx.moveTo left, top
        ctx.lineTo left, top+@tileH
        ctx.lineTo left+@tileW, top+@tileH
        ctx.lineTo left+@tileW, top
        ctx.closePath()
        ctx.fillStyle = color
        ctx.fill()
  }