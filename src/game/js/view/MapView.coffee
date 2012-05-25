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

      # side length of an hexagon.
      s = 50
      # dimensions of the square that embed an hexagon. 0.86 = Math.sin(60°)
      h = s*2*0.8660254037844386
      w = s*2

      # canvas dimensions (add 1 to take in account stroke width)
      width = w*10+1
      height = h*9+1

      # re-create the canvas element      
      canvas = $("<canvas width=\"#{width}\" height=\"#{height}\"></canvas>")
      @$el.append canvas 
      ctx = canvas[0].getContext('2d')

      # draw grid on it
      for y in [0.5..height] by h
        for x in [0.5..width] by w+s
          # draw only the upper part of the first hexagon, and the bottom-left edge
          ctx.moveTo x+s*0.5, y+h
          ctx.lineTo x, y+h*0.5
          ctx.lineTo x+s*0.5, y
          ctx.lineTo x+s*1.5, y
          ctx.lineTo x+w, y+h*0.5
          # then the the upper part of the second hexagon, and the bottom-right edge
          ctx.moveTo x+s*1.5, y+h
          ctx.lineTo x+w, y+h*0.5
          ctx.lineTo x+w+s, y+h*0.5
          ctx.lineTo x+w+s*1.5, y+h
          ctx.lineTo x+w+s, y+h*1.5

      ctx.strokeStyle = '#aaa'
      ctx.stroke()

      # for chaining purposes
      @

  return MapView