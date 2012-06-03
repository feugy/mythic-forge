define [
  'backbone'
  'jquery'
  'model/Item'
  'model/Field'
], (Backbone, $, Item, Field) ->

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

    # The map displayed.
    map: null,

    # Displayed game coordinate abscissa
    originX: 0 

    # Displayed game coordinate ordinate
    originY: 0

    # The router will act as an event bus.
    router: null

    # The images loader
    imagesLoader: null

    # the selected item. Null until an item is selected
    # the `selectedChanged` event is emitted when this attribute changes.
    selected: null

    # events mapping
    events:
      'click .layer.interactive': 'hitMap'
      'click .rule-trigger': 'triggerRule'
      'mousemove .layer.interactive': '_drawIndicator' 

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

    # **private**
    # Temporary stores fields by images while loading them, to display in block.
    _fieldsByImg: {}

    # **private**
    # This jumper avoid computing too frequently the hover indicator.
    _moveJumper: 0

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param map [Map] map to display.
    # @param collections [Array<Backbone.Collection>] Collections on which this view is bound
    # @param imagesLoader [ImagesLoader] the images loader
    # @param originX [Number] displayed game coordinate abscissa   
    # @param originY [Number] displayed game coordinate ordinate
    constructor: (@map, @originX, @originY, @router, collections, @imagesLoader) ->
      super {tagName: 'div'}
      for collection in collections
        collection.on 'add', @displayElement
        collection.on 'update', @displayElement
      @router.on 'rulesResolved', @_onRuleResolved
      @router.on 'imageLoaded', @_onImageLoaded
      @router.on 'key', @_onKeyUp


    # The `render()` method is invoked by backbone to display view content at screen.
    # draw a canvas with hexagons and coordinates.
    render: =>
      # consult the map content.      
      @map.consult {x: @originX, y: @originY}, {x: @originX+10, y: @originY+10}
      @$el.empty().addClass 'map'
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

      # creates the field canvas element      
      perspective.append "<canvas class=\"fields\" width=\"#{@_width}\" height=\"#{@_height}\"></canvas>"

      # creates the grid canvas element      
      canvas = $ "<canvas class=\"grid layer\" width=\"#{@_width}\" height=\"#{@_height}\"></canvas>"
      perspective.append canvas

      # another canvas for mouse indicator
      perspective.append "<canvas class=\"hover layer\" width=\"#{@_width}\" height=\"#{@_height}\"></canvas>"

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
          ctx.font = '12px sans-serif'
          ctx.fillStyle = '#eee'
          ctx.textAlign = 'center'
          ctx.textBaseline  = 'middle'
          if (gameX - @originX) <= 10
            ctx.fillText "#{gameX}:#{gameY}", x+@_hexW*0.5, y+@_hexH*0.5
            ctx.fillText "#{gameX}:#{gameY+1}", x+@_hexW, y+@_hexH*1.25 if (gameX - @originX) <= 10
        line += 2

      ctx.strokeStyle = '#eee'
      ctx.stroke()

      # for chaining purposes
      @

    # Method that displays above the map a single new item or field.
    #
    # @param item [element] the new item of field added to the collection.
    displayElement: (element) =>
      if element instanceof Item
        # removes previous rendering
        @_itemsLayer.find(".#{element.id}").remove()
        # do not display items that have not coordinates
        return if element.get('x') is null or element.get('y') is null

        console.log "display on map #{element.id} #{element.get 'name'} at #{element.get 'x'}:#{element.get 'y'}"

        # creates an image 
        src = "#{@router.origin}/assets/#{element.get('type').name}-#{element.get 'imageNum'}.png"
        img = $ "<img data-src=\"#{src}\" data-id=\"#{element.id}\" class=\"item #{element.id} #{element.get('type')._id}\"/>"
        @imagesLoader.load src
        x = element.get 'x'
        y = element.get 'y'
        left = @_hexW*(x+ if y%2 then 0.5 else 0)
        bottom = @_hexH*(@originY+10-y)*0.75

        @_itemsLayer.append img
        # depth correction
        correction = -(0.8*x-4)
        # absolute positionning it the item layer
        img.css 
          left: left
          bottom: bottom
          '-moz-transform': "skewX(#{correction}deg)"
          '-webkit-transform': "skewX(#{correction}deg)"
          # y is more important than x in z-index
          'z-index': y*2+x 

        # moves also selected indicator
        if @selected?.equals element
          selected = @_itemsLayer.find('.selected').detach()
          selected.css
            left: left
            bottom: bottom
          setTimeout =>
            @_itemsLayer.prepend(selected)
          , 50
      else 
        # this is a field. Load its image, and await for it.
        src = "#{@router.origin}/assets/sand-#{element.get 'imageNum'}.png"
        @_fieldsByImg[src] ?= [];
        @_fieldsByImg[src].push element
        @imagesLoader.load src

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

      pos = @_mousePosition mouse
      # now find an item with the relevant coordinates
      items = Item.collection.where pos
      if items.length > 0
        # we found someone: select it.
        @selectItem items[0]
      else if @selected?
        # trigger the resolution event
        @router.trigger 'resolveRules', @selected.id, pos.x, pos.y

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

    # Handler of image loading. Displays image on the map.
    #
    # @param success [Boolean] true if the image was correctly loaded
    # @param url [String] the image url
    # @param imageData [Object] if success, the image binary data
    _onImageLoaded: (success, url, imageData) =>
      if success
        # It's a afield
        if url of @_fieldsByImg
          return if @_fieldsByImg.length is 0
          fields = @_fieldsByImg[url]
          ctx =@$el.find('.fields')[0].getContext '2d'
          # Batch display of all concerned fields
          for field in fields
            # Draw image
            shift = if field.get('y')%2 is 0 then 0 else @_hexW*0.5
            ctx.drawImage imageData, 
              @_hexW * (field.get('x')-@originX) + shift, 
              @_hexH * .75 * (field.get('y')-@originY),
              @_hexW,
              @_hexH
        else 
          # it's an item.
          imgs = @$el.find "img[data-src=\"#{url}\"]"
          for img in imgs
            img = $(img)
            clone = $(imageData).clone()
            clone.attr 'class', img.attr 'class'
            clone.data 'id', img.data 'id'
            clone.css 
              left: img.css 'left'
              bottom: img.css 'bottom'
              '-moz-transform': img.css '-moz-transform'
              '-webkit-transform': img.css '-webkit-transform'
              'z-index': img.css 'z-index'
            img.replaceWith clone
    
    # Return the coordinate of the hexagon under the mouse position.
    # Inspired by [http://www-cs-students.stanford.edu/~amitp/Articles/GridToHex.html] and
    # [http://www.blackpawn.com/texts/pointinpoly/default.html]
    #
    # @param mouse [Object] mouse screen position, relative to the interactive layer.
    # @option mouse x [Number] abscissa of the mouse
    # @option mouse y [Number] ordinate of the mouse
    # @return the map coordinate of the hovered hexagon.
    _mousePosition: (mouse) =>
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
      {x: col, y:row}

    # Handler that displays an hexagonal indicator under the mouse.
    #
    # @param event [Event] mouse mouve event.      
    _drawIndicator: (event) =>
      return unless @_moveJumper++ % 3 is 0
      # gets the mouse position.
      mouse =
        x: if $.browser.webkit then event.offsetX else event.originalEvent.layerX
        y: if $.browser.webkit then event.offsetY else event.originalEvent.layerY
      pos = @_mousePosition mouse
      x = pos.x * @_hexW + if pos.y%2 is 0 then 0 else @_hexW*0.5
      y = pos.y * @_hexH * 0.75

      # erases previous indicator
      ctx = @$el.find('.hover').attr('width', @_width)[0].getContext '2d'
      
      # draws an hexagon
      ctx.moveTo x+@_hexW*.5, y
      ctx.lineTo x, y+@_hexH*.25
      ctx.lineTo x, y+@_hexH*.75
      ctx.lineTo x+@_hexW*.5, y+@_hexH
      ctx.lineTo x+@_hexW, y+@_hexH*.75
      ctx.lineTo x+@_hexW, y+@_hexH*.25
      ctx.lineTo x+@_hexW*.5, y
      ctx.strokeStyle = '#f00'
      ctx.stroke()

    # Key handler. Trigger the move rule on adjacent fields if possible.
    #
    # @param key [Object] description of the key press.
    # @option key code [Number] key code pressed
    # @option key shift [Boolean] true id shift is pressed
    # @option key ctrl [Boolean] true id control is pressed
    # @option key meta [Boolean] true id meta is pressed
    _onKeyUp: (key) =>
      return unless @selected?
      targetId = null
      pos = 
        x: @selected.get 'x'
        y: @selected.get 'y'
      switch key.code
        # numpad 1
        when 97 
          pos.x-- if pos.y % 2 is 0
          pos.y++
        # numpad 4
        when 100 then pos.x--
        # numpad 7
        when 103
          pos.x-- if pos.y % 2 is 0
          pos.y--
        # numpad 3
        when 99
          pos.x++ if pos.y % 2 is 1
          pos.y++
        # numpad 6
        when 102 then pos.x++
        # numpad 9
        when 105
          pos.x++ if pos.y % 2 is 1
          pos.y--
        else 
          return
      # trigger the rule move if possible.
      targets = Field.collection.where pos
      @router.trigger 'executeRule', 'move', @selected.id, targets[0].id if targets.length is 1

  return MapView