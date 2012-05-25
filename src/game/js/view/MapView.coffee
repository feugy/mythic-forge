define [
  'lib/backbone'
  'lib/jquery'
], (Backbone, $) ->

  class MapView extends Backbone.View

    constructor: (options) ->
      options ||= {}
      options.tagName ||= 'span'
      super options

    render: =>
      console.log "Render map view #{@cid}"

      ### vertical hexagons
       side length of an hexagon.
      s = 50
       dimensions of the square that embed an hexagon.
       the angle used reflect the perspective effect. 60° > view from above. 45° > isometric perspective
      h = s*Math.tan(45*Math.PI/180)
      w = s*2
      ###

      # horizontal hexagons: side length of an hexagon.
      s = 50
      # dimensions of the square that embed an hexagon.
      # the angle used reflect the perspective effect. 60° > view from above. 45° > isometric perspective
      h = s*Math.sin(45*Math.PI/180)*2
      w = s*2

      # canvas dimensions (add 1 to take in account stroke width)
      width = w*10+1
      height = h*7+1

      # re-create the canvas element      
      canvas = $("<canvas width=\"#{width}\" height=\"#{height}\"></canvas>")
      @$el.append canvas 
      ctx = canvas[0].getContext('2d')

      # draw grid on it
      ### vertical hexagons
      for y in [0.5..height] by h
        for x in [0.5..width] by w+s
      ###

      for y in [0.5..height] by h*1.5
        for x in [0.5..width] by w
          # horizontal hexagons
          # draw only the upper part of the first hexagon, and the bottom-left edge
          ctx.moveTo x+w, y+h*0.25
          ctx.lineTo x+w*0.5, y
          ctx.lineTo x, y+h*0.25
          ctx.lineTo x, y+h*0.75
          ctx.lineTo x+w*0.5, y+h
          # then the the upper part of the second hexagon, and the bottom-right edge
          ctx.moveTo x+w, y+h*0.75
          ctx.lineTo x+w*0.5, y+h
          ctx.lineTo x+w*0.5, y+h*1.5
          ctx.lineTo x+w, y+h*1.75
          ctx.lineTo x+w*1.5, y+h*1.5

          ### vertical hexagons
           draw only the upper part of the first hexagon, and the bottom-left edge
          ctx.moveTo x+s*0.5, y+h
          ctx.lineTo x, y+h*0.5
          ctx.lineTo x+s*0.5, y
          ctx.lineTo x+s*1.5, y
          ctx.lineTo x+w, y+h*0.5
           then the the upper part of the second hexagon, and the bottom-right edge
          ctx.moveTo x+s*1.5, y+h
          ctx.lineTo x+w, y+h*0.5
          ctx.lineTo x+w+s, y+h*0.5
          ctx.lineTo x+w+s*1.5, y+h
          ctx.lineTo x+w+s, y+h*1.5
          ###

      ctx.strokeStyle = '#aaa'
      ctx.stroke()

      # for chaining purposes
      @

  return MapView