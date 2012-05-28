define [
  'lib/backbone'
  'lib/jquery'
  'model/Item'
], (Backbone, $, Item) ->

  # **private**
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

  # The map view uses a canvas to display an hexagonal grid, and images to display items on it
  #
  class MapView extends Backbone.View

    # Items collection to which this view is bound
    collection: null

    # Displayed game coordinate abscissa
    originX: 0 

    # Displayed game coordinate ordinate
    originY: 0

    # The router will act as an event bus.
    router: null

    # the selected item. Null until an item is selected
    # the `selectedChanged` event is emitted when this attribute changes.
    selected: null

    # events mapping
    events:
      'click .layer.interactive': 'hitMap'
      'click .rule-trigger': 'triggerRule'

    # **private**
    # Items layer jQuery element.
    _itemsLayer: null

    # **private**
    # Hexagon width in pixel.
    _hexW: 0

    # **private**
    # Hexagon height in pixel.
    _hexH: 0

    # **private**
    # Total width of the displayed map.
    _width: 0

    # **private**
    # Total height of the displayed map.
    _height: 0

    # The view constructor.
    #
    # @param options [Object] view's attributes. 
    # @option options originX [Number] displayed game coordinate abscissa   
    # @option options originY [Number] displayed game coordinate ordinate
    constructor: (options) ->
      options.tagName ||= 'span'
      super options
      @collection.on 'add', @displayItem
      @collection.on 'update', @displayItem
      @router = options.router
      @router.on 'rulesResolved', @_onRuleResolved

    # The `render()` method is invoked by backbone to display view content at screen.
    # draw a canvas with hexagons and coordinates.
    render: =>
      @$el.empty()
      console.log "Render map view #{@cid}"
      # horizontal hexagons: side length of an hexagon.
      s = 50
      # dimensions of the square that embed an hexagon.
      # the angle used reflect the perspective effect. 60° > view from above. 45° > isometric perspective
      @_hexH = s*Math.sin(45*Math.PI/180)*2
      @_hexW = s*2

      # canvas dimensions (add 1 to take in account stroke width)
      @_width = @_hexW*11.5+1
      @_height = @_hexH*8.5+1

      perspective = $ '<div class="perspective"></div>'
      @$el.append perspective

      # creates the canvas element      
      canvas = $ "<canvas width=\"#{@_width}\" height=\"#{@_height}\"></canvas>"
      perspective.append canvas

      # then creates the item layer
      @_itemsLayer = $ '<div class="layer items"></div>'
      perspective.append @_itemsLayer 

      # at last, add an interractive layer
      perspective.append '<div class="layer interactive"></div>'
  
      ctx = canvas[0].getContext('2d')
      ctx.fillStyle = '#aaa'
      # draw grid on it
      line = 0
      for y in [0.5..@_height] by @_hexH*1.5
        for x in [0.5..@_width] by @_hexW
          gameX = @originX + parseInt x/@_hexW
          gameY = @originY + line
            
          # horizontal hexagons
          # first hexagon: starts from top-right summit, and draws counter-clockwise until bottom summit
          if (gameX - @originX) <= 10
            ctx.moveTo x+@_hexW, y+@_hexH*0.25
            ctx.lineTo x+@_hexW*0.5, y
            ctx.lineTo x, y+@_hexH*0.25
          else 
            # end of the drawing: just close the previous hexagon.
            ctx.moveTo x, y+@_hexH*0.25
          ctx.lineTo x, y+@_hexH*0.75
          unless gameX - @originX > 10 and gameY - @originY is 10
            ctx.lineTo x+@_hexW*0.5, y+@_hexH
          # second hexagon: starts from top summit, and draws counter-clockwise until bottom-right summit
          if (gameX - @originX) <= 10
            ctx.moveTo x+@_hexW, y+@_hexH*0.75
            ctx.lineTo x+@_hexW*0.5, y+@_hexH
          else 
            # end of the drawing: just close the previous hexagon.
            ctx.moveTo x+@_hexW*0.5, y+@_hexH
          ctx.lineTo x+@_hexW*0.5, y+@_hexH*1.5
          ctx.lineTo x+@_hexW, y+@_hexH*1.75
          ctx.lineTo x+@_hexW*1.5, y+@_hexH*1.5
          # add coordinates
          ctx.font = 'bold 12px sans-serif'
          ctx.textAlign = 'center'
          ctx.textBaseline  = 'middle'
          if (gameX - @originX) <= 10
            ctx.fillText "#{gameX}:#{gameY}", x+@_hexW*0.5, y+@_hexH*0.5
            ctx.fillText "#{gameX}:#{gameY+1}", x+@_hexW, y+@_hexH*1.25 if (gameX - @originX) <= 10
        line += 2

      ctx.strokeStyle = '#aaa'
      ctx.stroke()

      # for chaining purposes
      @

    # Method that displays above the map a single new item.
    #
    # @param item [Item] the new item added to the collection.
    displayItem: (item) =>
      # removes previous rendering
      @_itemsLayer.find(".#{item.get('_id')}").remove()
      # do not display items that have not coordinates
      return if item.get('x') is null or item.get('y') is null

      console.log "display on map #{item.get('_id')} #{item.get('name')} at #{item.get('x')}:#{item.get('y')}"

      # creates an image 
      img = $ "<img data-id=\"#{item.id}\" \
          class=\"item #{item.id} #{item.get('type')._id}\" \
          src=\"assets/#{item.get 'imageNum'}.png\"/>"
      @_itemsLayer.append img
      # depth correction
      x = item.get 'x'
      y = item.get 'y'
      correction = -(0.8*x-4)
      # absolute positionning it the item layer
      img.css 
        left: @_hexW*(x+ if y%2 then 0.5 else 0)
        bottom: @_hexH*(@originY+10-y)*0.75
        '-moz-transform': "skewX(#{correction}deg)"
        '-webkit-transform': "skewX(#{correction}deg)"
      # moves also selected indicator
      if @selected?.equals item
        @_itemsLayer.find('.selected').css
          left: img.css 'left'
          bottom: img.css 'bottom'

    # Method that selects an item for rules resolution and execution.
    # If the item specified is already selected, unselect it.
    # the `selectedChanged` event is published on the router.
    #
    # @param item [Item] the item to select.
    selectItem: (item) =>
      return unless item?
      # gets the corresponding image
      img = @$el.find "img.#{item.id}"
      return if img.length is 0

      # remove previous selection.
      @_itemsLayer.find('.selected').remove()
      # deselect the current selected item
      if @selected?.id isnt item.id
        # and add a new selected item
        selected = $ '<div class="selected"></div>'
        selected.css 
          left: img.css 'left'
          bottom: img.css 'bottom'
        @_itemsLayer.prepend selected
      else 
        item = null

      @selected = item
      console.log "selected item: #{@selected?.id}"
      @router.trigger 'selectedChanged', @selected

    # Method bound to a click on the map.
    # Find the corresponding hexagon.
    # If a item is on it, select it with the selectItem() method.
    # Otherwise, and if an item is selected, triggers the event `resolveRules` on the router
    # 
    # @param event [Event] click event on the element
    hitMap: (event) =>
      # gets the real coordinates
      mouse =
        x: if $.browser.webkit then event.offsetX else event.originalEvent.layerX
        y: if $.browser.webkit then event.offsetY else event.originalEvent.layerY

      # inspired by [http://www-cs-students.stanford.edu/~amitp/Articles/GridToHex.html] and
      # [http://www.blackpawn.com/texts/pointinpoly/default.html]

      # locate the upper rectangle in which the mouse hit
      row = Math.floor mouse.y/(@_hexH*0.75)
      if row%2
        mouse.x -= @_hexW*0.5
      col = Math.floor mouse.x/@_hexW

      # upper summit of the hexagon
      a = 
        x: (col+0.5)*@_hexW
        y: @_height-row*@_hexH*0.75
      # top-right summit of the hexagon
      b = 
        x: (col+1)*@_hexW
        y: @_height-(row+0.25)*@_hexH*0.75
      # top-left summit of the hexagon
      c = 
        x: col*@_hexW
        y: b.y
      # need to get in a plan here upper means greater y.
      mouse.y = @_height-mouse.y

      # if the hit fell in the upper right triangle, it's in the hexagon above and right
      if _isAbove mouse, a, b
        col++ if row % 2
        row--
      # or if the hit fell in the upper left triangle, it's in the hexagon above and left
      else if _isAbove mouse, c, a
        col-- unless row % 2
        row--
      # or it's the good hexagon :)

      console.log "mouse #{mouse.x}:#{mouse.y} -> #{col}:#{row}"
      # now find an item with the relevant coordinates
      items = Item.collection.where {x: col, y:row}
      if items.length > 0
        # we found someone: select it.
        @selectItem items[0]
      else if @selected?
        # trigger the resolution event
        @router.trigger 'resolveRules', @selected.id, col, row

    # trigger the rule resolution from a contextual menu.
    #
    # @param event [Event] the click event.
    triggerRule: (event) =>
      return unless @selected?
      ruleName = $(event.target).data 'name'
      targetId = $(event.target).data 'target'
      # Delegates to someone else the execution.
      @router.trigger 'executeRule', ruleName, @selected.id, targetId
      @$el.find('.menu.rules').remove()

    # Display a menu with the different applicable rules for the actor.
    #
    # @param args [Object] resolution arguments: 
    # @option args actorId [String] id of the concerned actor
    # @option args x [Number] x coordinate of the resolution
    # @option args y [Number] y coordinate of the resolution
    # @param results [Object] the matching rules, stored in arrays and grouped by target ids
    _onRuleResolved: (args, results) =>
      @$el.find('.menu.rules').remove()
      # retrieve the actor.
      actor = Item.collection.get args.actorId
      return unless actor?
      # gets the actor corresponding image
      img = @$el.find "img.#{args.actorId}"
      return if img.length is 0
      str = ''
      for id, rules of results
        str += "<li class=\"rule-trigger\" data-target=\"#{id}\" data-name=\"#{rule.name}\">#{rule.name}</li>" for rule in rules
      if str.length isnt 0
        $("<div class=\"menu rules\"><ul>#{str}</ul></div>").css
          left: args.x*@_hexW
          top: args.y*@_hexH
        .appendTo @$el

  return MapView