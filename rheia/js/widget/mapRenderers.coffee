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
  'widget/authoringMap'
],  (Map) ->

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
    hexagon: class HexagonRenderer extends Map.Renderer

      # Initiate the renderer with map inner state. 
      # Value attributes `height`, `width`, `tileW` and `tileH`
      #
      # @param map [Object] the associated map widget
      # 
      init: (map) =>
        @map = map
        # horizontal hexagons: side length of an hexagon.
        s = map.options.tileDim/2

        # dimensions of the square that embed an hexagon.
        # the angle used reflect the perspective effect. 60° > view from above. 45° > isometric perspective
        @tileH = s*map.options.zoom*2*Math.sin map.options.angle*Math.PI/180
        @tileW = s*map.options.zoom*2

        # canvas dimensions (add 1 to take in account stroke width, and no zoom)
        @width = 1+map.options.horizontalTileNum*@tileW/map.options.zoom
        @height = 1+map.options.verticalTileNum*@tileH*0.75/map.options.zoom 

        @origin = @nextCorner map.options.lowerCoord, true

      # **private**
      # Returns the number of tile within the map total height.
      # Used to reverse the ordinate axis.
      #
      # @return number of tile in total map height
      _verticalTotalNum: () => 
        (-1 + Math.floor @height*3/@tileH*0.75)*3

      # Compute the map coordinates of the other corner of displayed rectangle
      #
      # @param coord [Object] map coordinates of the upper/lower corner used as reference
      # @param upper [Boolean] indicate the the reference coordinate are the upper-right corner. 
      # False to indicate its the bottom-left corner
      # @return map coordinates of the other corner
      nextCorner: (coord, upper=false) => 
        # displayed view is a parallelepiped with a 60 degree angle
        opposite = Math.tan(30*Math.PI/180)*@height
        numInOpposite = Math.ceil opposite/@tileW

        row = Math.floor @height/(@tileH*0.75)
        col = Math.floor @width/@tileW
        {
          x: coord.x + if upper then numInOpposite*3-col else col+numInOpposite*2
          y: coord.y + if upper then -row else row
        }

      # Translate map coordinates to css position (relative to the map origin)
      #
      # @param coord [Object] object containing x and y coordinates
      # @option coord x [Number] object abscissa
      # @option coord y [Number] object ordinates
      # @return an object containing:
      # @option return left [Number] the object's left offset, relative to the map origin
      # @option return top [Number] the object's top offset, relative to the map origin
      # @option return z-index [Number] the object's z-index
      coordToPos: (coord) =>
        left = (coord.x - @origin.x) * @tileW
        y = coord.y - @origin.y
        # invert y axis
        top = @height*3 - ((y + 1)*0.75 + 0.25) * @tileH
        # shift left on even rows
        left -= @tileW*0.5 if Math.floor (top/(@tileH*0.75))%2
        # shift right the left coordinate for each rows
        left += Math.ceil(y/2)*@tileW
        {
          # left may be shifted on even rows
          left: left
          top: top
          # for z-index, row is more important than column
          'z-index': (@_verticalTotalNum()-y)*2 + coord.x 
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
        # locate the upper rectangle in which the mouse hit, with reverted y axis
        row = Math.floor (@height*3-pos.top)/(@tileH*0.75)
        shift = 0
        if row % 2 is 1
          shift = @tileW*0.5
        col = Math.floor (pos.left+shift)/@tileW
        
        pos.x = pos.left
        pos.y = pos.top
        # bottom summit of the hexagon
        a = 
          x: (col+0.5)*@tileW-shift
          y: @height*3-row*(@tileH*0.75)-2
        # bottom-right summit of the hexagon
        b = 
          x: (col+1)*@tileW-shift
          y: @height*3-(row+0.25)*(@tileH*0.75)-2
        # bottom-left summit of the hexagon
        c = 
          x: col*@tileW-shift
          y: b.y

        if _isBelow pos, c, a
          # if the hit fell in the lower left triangle, it's in the hexagon below and left
          row--
          col-- unless row % 2
        else if _isBelow pos, a, b
          # or if the hit fell in the lower right triangle, it's in the hexagon below and right
          row--
          col++ if row % 2

        # or it's the good hexagon :)
        y = row+@origin.y
        {
          x: col+@origin.x-Math.ceil row/2
          y: y
        }

      # Draws the grid wireframe on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawGrid: (ctx) =>
        # draw grid on it, with revert ordinate axis
        step = -@tileH*1.5
        for y in [@height*3-0.5..0.5] by step
          for x in [0.5..@width*3] by @tileW    
            # horizontal hexagons
            # first hexagon: starts from bottom-right summit, and draws clockwise until top summit
            ctx.moveTo x+@tileW, y-@tileH*0.25
            ctx.lineTo x+@tileW*0.5, y
            ctx.lineTo x, y-@tileH*0.25
            ctx.lineTo x, y-@tileH*0.75
            ctx.lineTo x+@tileW*0.5, y-@tileH
            # second hexagon: starts from bottom summit, and draws clockwise until top-right summit
            ctx.moveTo x+@tileW, y-@tileH*0.75
            ctx.lineTo x+@tileW*0.5, y-@tileH
            ctx.lineTo x+@tileW*0.5, y-@tileH*1.5
            ctx.lineTo x+@tileW, y-@tileH*1.75
            ctx.lineTo x+@tileW*1.5, y-@tileH*1.5
            
        ctx.stroke()

      # Draws the markers on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawMarkers: (ctx) =>
        # initialise a line number, starting from the bottom and going up
        step = -@tileH*1.5
        gameY = @origin.y
        originX = @origin.x
        originX-- if @origin.y%2
        for y in [@height*3-0.5..0.5] by step
          for x in [0.5..@width*3] by @tileW    
            gameX = originX + Math.floor x/@tileW

            if gameX % 5 is 0
              if gameY % 5 is 0
                ctx.fillText "#{gameX}:#{gameY}", x+@tileW*0.5, y-@tileH*0.5
              else if gameY > 0 and gameY % 5 is 4 or gameY < 0 and gameY % 5 is -1
                ctx.fillText "#{gameX}:#{gameY+1}", x+@tileW*((Math.abs(@origin.y)+1) % 2), y-@tileH*1.25

          gameY += 2
          originX--

      # Draw a single selected tile in selection or to highlight hover
      #
      # @param ctx [Canvas] the canvas context.
      # @param pos [Object] coordinate of the drew tile
      # @param color [String] the color used to fill the tile
      drawTile: (ctx, coord, color) =>
        ctx.beginPath()
        {left, top} = @coordToPos coord
        # draws an hexagon
        ctx.moveTo left+@tileW*.5, top
        ctx.lineTo left, top+@tileH*.25
        ctx.lineTo left, top+@tileH*.75
        ctx.lineTo left+@tileW*.5, top+@tileH
        ctx.lineTo left+@tileW, top+@tileH*.75
        ctx.lineTo left+@tileW, top+@tileH*.25
        ctx.closePath()
        ctx.fillStyle = color
        ctx.fill()

      # Place the movable layers after a move
      #
      # @param move [Object] map coordinates (x and y) of the movement
      # @return screen offset (left and top) of the movable layers
      replaceMovable: (move) =>
        top = move.y*@tileH*0.75
        row = Math.ceil(@height*3-top)/(0.75*@tileH)
        {
          left: (Math.floor(-move.y/2)-move.x+(if 0 is Math.floor row%2 then 0 else 0.5))*@tileW
          top: top
        }
        
      # Place the container itself after a move.
      #
      # @param pos [Object] current screen position (left and top) of the container
      # @return screen offset (left and top) of the container
      replaceContainer: (pos) =>
        {
          left: -@width+(pos.left/@tileW)-(pos.left%@tileW)
          top: -@height+(pos.top/(@tileH*0.75))-(pos.top%(@tileH*0.75))
        }

    # Diamond renderer creates isometric maps.
    # In terms of map coordinates, lowerCoord is displayed at upper-left corner, and upperCoord at lower-right corner.
    diamond: class DiamondRenderer extends Map.Renderer

      # Initiate the renderer with map inner state. 
      # Value attributes `height`, `width`, `tileW` and `tileH`.
      #
      # @param map [Object] the associated map widget
      # 
      init: (map) =>
        @map = map
        # dimensions of the square that embed an diamond.
        @tileH = map.options.tileDim*map.options.zoom*Math.sin map.options.angle*Math.PI/180
        @tileW = map.options.tileDim*map.options.zoom

        # canvas dimensions (add 1 to take in account stroke width, and no zoom)
        @width = 1+map.options.horizontalTileNum*@tileW/map.options.zoom
        @height = 1+map.options.verticalTileNum*@tileH/map.options.zoom

        @origin = @nextCorner map.options.lowerCoord, true

      # **private**
      # Returns the number of tile within the map total height.
      # Used to reverse the ordinate axis.
      #
      # @return number of tile in total map height
      _verticalTotalNum: () => 
        (-1 + Math.floor @height*3/@tileH*0.5)*3

      # Compute the map coordinates of the other corner of displayed rectangle
      #
      # @param coord [Object] map coordinates of the upper/lower corner used as reference
      # @param upper [Boolean] indicate the the reference coordinate are the upper-right corner. 
      # False to indicate its the bottom-left corner
      # @return map coordinates of the other corner
      nextCorner: (coord, upper=false) => 
        if upper
          offsetW = @height*0.5*Math.tan @map.options.angle*Math.PI/180
          tileW = @tileW/@map.options.zoom  
          tileH = @tileH/@map.options.zoom

          sav = x:@origin.x, y:@origin.y
          @origin = x:0, y:0
          # with an origin at 0:0, found the coordinate of the opposite searched point
          # the search point is at @height=1.5 and @-width-offsetW
          # shift by tile width and height to tackle posToCoord round operations 
          res = @posToCoord top: -tileH+@height*4.5, left: tileW*3-@width+offsetW
          @origin = sav
          {
            x: coord.x + res.x
            y: coord.y + res.y
          }
        else
          sin = Math.sin @map.options.angle*Math.PI/180
          # use a rectangular triangle below left edge of displayed area
          # triangle's top corner is `angle`, triangle's bottom edge is `@height/2` 
          hypoLeft = (@height*0.5)/sin
          # use a rectangular triangle above top edge of displayed area
          # triangle's top corner is `angle`, triangle's bottom edge is `@width/2` 
          hypoTop = (@width*0.5)/sin
          # but we need to correct error due to misplacing the origin...
          error = @tileW*2/(@map.options.zoom*sin)
          # compute square edge's length
          hypoSquare = @tileW*0.5/sin
          edge = Math.ceil (hypoLeft+hypoTop+error)/hypoSquare
          {
            x: coord.x + edge
            y: coord.y + edge
          }

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
        col = obj.x - @origin.x
        row = obj.y - @origin.y
        {
          left: (col+row)*@tileW/2
          top: @height*3-(2-col+row)*@tileH/2
          # for z-index, column is more important than row (which is inverted)
          'z-index': (@_verticalTotalNum()-obj.y+@origin.y) + obj.x*2 
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
        # locate the upper rectangle in which the mouse hit, with reverted y axis
        row = Math.floor (@height*3-pos.top)/(@tileH*0.5)
        shift = 0
        xShift = 0
        if row % 2 is 1
          shift = @tileW*0.5
          xShift = -1
        col = Math.floor (pos.left+shift)/@tileW
        
        pos.x = pos.left
        pos.y = pos.top
        # bottom summit of the diamond
        a = 
          x: (col+0.5)*@tileW-shift
          y: @height*3-row*@tileH*0.5
        # right summit of the diamond
        b = 
          x: (col+1)*@tileW-shift
          y: @height*3-(row+1)*@tileH*0.5
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
          x: @origin.x - row + col + xShift
          y: @origin.y + row + col
        }

      # Draws the grid wireframe on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawGrid: (ctx) =>
        i = 0
        for y in [@height*3-0.5..0.5] by -@tileH*0.5
          for x in [0.5..@width*3] by @tileW
            # even rows are shifted by 1/2 width
            shift = if i%2 then @tileW*0.5 else 0
            # draw a diamond counter-clockwise from top summit
            ctx.moveTo x+shift+@tileW*0.5, y-@tileH
            ctx.lineTo x+shift, y-@tileH*0.5
            ctx.lineTo x+shift+@tileW*0.5, y
            ctx.lineTo x+shift+@tileW, y-@tileH*0.5
            ctx.lineTo x+shift+@tileW*0.5, y-@tileH
          i++
        ctx.stroke()

      # Draws the markers on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawMarkers: (ctx) =>
        row = 0
        for y in [@height*3-0.5..0.5] by -@tileH
          col = 0
          for x in [0.5..@width*3] by @tileW    
            gameX = @origin.x - row + col
            gameY = @origin.y + row + col

            if gameX % 5 is 0
              if gameY % 5 is 0
                ctx.fillText "#{gameX}:#{gameY}", x+@tileW*0.5, y-@tileH*0.5
              else if gameY > 0 and gameY % 5 is 4 or gameY < 0 and gameY % 5 is -1
                ctx.fillText "#{gameX}:#{gameY+1}", x+@tileW, y-@tileH
            col++
          row++


      # Draw a single selected tile in selection or to highlight hover
      #
      # @param ctx [Canvas] the canvas context.
      # @param coord [Object] coordinate of the drew tile
      # @param color [String] the color used to fill the tile
      drawTile: (ctx, coord, color) =>
        ctx.beginPath()
        {left, top} = @coordToPos coord
        # draws a diamond
        ctx.moveTo left+@tileW*.5, top
        ctx.lineTo left, top+@tileH*.5
        ctx.lineTo left+@tileW*.5, top+@tileH
        ctx.lineTo left+@tileW, top+@tileH*0.5
        ctx.closePath()
        ctx.fillStyle = color
        ctx.fill()
        
      # Place the movable layers after a move
      #
      # @param move [Object] map coordinates (x and y) of the movement
      # @return screen offset (left and top) of the movable layers
      replaceMovable: (move) =>
        {
          left: (-move.x-move.y)*@tileW/2
          top: (-move.x+move.y)*@tileH/2
        }
        
      # Place the container itself after a move.
      #
      # @param pos [Object] current screen position (left and top) of the container
      # @return screen offset (left and top) of the container
      replaceContainer: (pos) =>
        {
          left: -@width+(pos.left/@tileW)-(pos.left%@tileW)
          top: -@height+(pos.top/(@tileH*0.5))-(pos.top%(@tileH*0.5))
        }

    # Square renderer creates classic checkerboard maps
    square: class SquareRenderer extends Map.Renderer

      # Initiate the renderer with map inner state.
      # Value attributes `height`, `width`, `tileW` and `tileH`
      #
      # @param map [Object] the associated map widget
      # 
      init: (map) =>
        @map = map
        # dimensions of the square.
        @tileH = map.options.tileDim*map.options.zoom
        @tileW = map.options.tileDim*map.options.zoom

        # canvas dimensions (add 1 to take in account stroke width, and no zoom)
        @width = 1+map.options.horizontalTileNum*@tileW/map.options.zoom
        @height = 1+map.options.verticalTileNum*@tileH/map.options.zoom 

        @origin = @nextCorner map.options.lowerCoord, true

      # Compute the map coordinates of the other corner of displayed rectangle
      #
      # @param coord [Object] map coordinates of the upper/lower corner used as reference
      # @param upper [Boolean] indicate the the reference coordinate are the upper-right corner. 
      # False to indicate its the bottom-left corner
      # @return map coordinates of the other corner
      nextCorner: (coord, upper=false) => 
        row = Math.floor @height/@tileH
        col = Math.floor @width/@tileW
        {
          x: coord.x + if upper then -col else col+1
          y: coord.y + if upper then -row else row+1
        }

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
        {
          left: (obj.x - @origin.x)*@tileW
          top: @height*3-(obj.y + 1 - @origin.y)*@tileH
          # for z-index, inverted rows is more important 
          'z-index': (@_verticalTotalNum()-obj.y+@origin.y)*2+obj.x 
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
        {
          y: @origin.y + Math.floor (@height*3-pos.top)/@tileH
          x: @origin.x + Math.floor pos.left/@tileW
        }

      # Draws the grid wireframe on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawGrid: (ctx) =>
        i = 0
        # draws horizontal lines starting from bottom
        for y in [@height*3-1..0] by -@tileH
          ctx.moveTo 0, y
          ctx.lineTo @width*3, y

        # draws vertical lines
        for x in [1..@width*3] by @tileW
          ctx.moveTo x, 0
          ctx.lineTo x, @height*3
        ctx.stroke()

      # Draws the markers on a given context.
      #
      # @param ctx [Object] the canvas context on which drawing
      drawMarkers: (ctx) =>
        row = 0
        for y in [@height*3-1..0] by -@tileH
          gameY = @origin.y + row++
          if gameY % 5 is 0
            col = 0
            for x in [1..@width*3] by @tileW    
              gameX = @origin.x + col++
              if gameX % 5 is 0
                ctx.fillText "#{gameX}:#{gameY}", x+@tileW*0.5, y-@tileH*0.5

      # Draw a single selected tile in selection or to highlight hover
      #
      # @param ctx [Canvas] the canvas context.
      # @param pos [Object] coordinate of the drew tile
      # @param color [String] the color used to fill the tile
      drawTile: (ctx, coord, color) =>
        ctx.beginPath()
        {left, top} = @coordToPos coord
        # draws a square
        ctx.moveTo left, top
        ctx.lineTo left, top+@tileH
        ctx.lineTo left+@tileW, top+@tileH
        ctx.lineTo left+@tileW, top
        ctx.closePath()
        ctx.fillStyle = color
        ctx.fill()

      # Place the movable layers after a move
      #
      # @param move [Object] map coordinates (x and y) of the movement
      # @return screen offset (left and top) of the movable layers
      replaceMovable: (move) =>
        {
          left: -move.x*@tileW
          top: move.y*@tileH
        }
        
      # Place the container itself after a move.
      #
      # @param pos [Object] current screen position (left and top) of the container
      # @return screen offset (left and top) of the container
      replaceContainer: (pos) =>
        {
          left: -@width+(pos.left/@tileW)-(pos.left%@tileW)
          top: -@height+(pos.top/@tileH)-(pos.top%@tileH)
        }
  }