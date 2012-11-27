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
  'utils/utilities'
  'widget/loadableImage'
],  ($, utils, LoadableImage) ->

  defaultHeight = 100;
  defaultWidth = 100;

  # List of executing animations
  _anims = []

  # The unic animation loop
  _loop = (time) ->
    # request another animation frame for next rendering.
    window.requestAnimationFrame _loop 
    if document.hidden
      # if document is in background, animations will stop, so stop animations.
      time = null
    # trigger onFrame for each executing animations
    for anim in _anims
      anim._onFrame.call anim, time if anim isnt undefined

  # starts the loop at begining of the game
  _loop new Date().getTime()

  # Widget that renders an item inside a map Item.
  # Manage its position and its animations
  class MapItem extends LoadableImage

    # **private**
    # Model images specification
    _imageSpec: null

    # **private**
    # Currently displayed sprite: name of one of the _imageSpec sprite
    _sprite: null

    # **private**
    # Current sprite image index
    _step: 0

    # **private**
    # Current sprite image offset
    _offset: {x:0, y:0}

    # **private**
    # Animation start timestamp
    _start:null

    # **private**
    # Stored coordinates applied at the end of the next animation
    _newCoordinates: null

    # **private**
    # Stored position applied at the end of the next animation
    _newPos: null

    # Builds rendering. Image is computed from the model type image and instance number
    constructor: (element, options) ->
      # compute item image
      @_imageSpec = options.model.type.images?[options.model.imageNum] 
      options.source = @_imageSpec?.file or options.model.type.descImage

      super element, options
      
      @$el.addClass 'map-item'

      @_image.replaceWith '<div class="image"></div>'
      @_image = @$el.find '.image'

      # bind to model events
      @bindTo @options.model, 'update',  @_onUpdate
      @bindTo @options.model, 'destroy', => @$el.remove()

    # **private**
    # Compute and apply the position of the current widget inside its map widget.
    # In case of position deferal, the new position will be slighly applied during next animation
    #
    # @param defer [Boolean] allow to differ the application of new position. false by default
    _positionnate: (defer = false) =>
      return unless @_imageSpec?
      return unless @options.map?
      coordinates = 
        x: @options.model.x
        y: @options.model.y

      o = @options.map.options

      # get the widget cell coordinates
      pos = o.renderer.coordToPos coordinates
      
      # center horizontally with tile, and make tile bottom and widget bottom equal
      pos.left += (o.renderer.tileW-@_imageSpec.width*o.zoom)/2 
      pos.top += o.renderer.tileH-@_imageSpec.height*o.zoom

      # add perspective correction
      pos['-moz-transform'] = "scale(#{o.zoom})"
      pos['-webkit-transform'] = "scale(#{o.zoom})"

      if defer 
        # do not apply immediately the new position
        @_newCoordinates = coordinates
        @_newPos = pos
      else
        @options.coordinates = coordinates
        @$el.css pos

    # **private**
    # Shows relevant sprite image regarding the current model animation and current timing
    _renderSprite: =>
      return unless @_imageSpec?
      # do we have a transition ?
      transition = @options.model.getTransition()
      transition = null unless @_imageSpec.sprites? and transition of @_imageSpec.sprites

      # gets the item sprite's details.
      if 'object' is utils.type @_imageSpec.sprites
        @_sprite = @_imageSpec.sprites[transition or Object.keys(@_imageSpec.sprites)[0]]
      else
        @_sprite = null

      @_step = 0
      # set the sprite row
      @_offset.x = 0
      @_offset.y = if @_sprite? then -@_sprite.rank * @_imageSpec.height else 0

      # no: just display the sprite image
      @_image.css {'background-position': "#{@_offset.x}px #{@_offset.y}px"}
      return unless transition?

      # yes: let's start the animation !
      @_start = new Date().getTime()

      # if we moved, compute the steps
      if @_newPos?
        @_newPos.stepL = (@_newPos.left-parseInt @$el.css 'left')/@_sprite.number
        @_newPos.stepT = (@_newPos.top-parseInt @$el.css 'top')/@_sprite.number

      if document.hidden
        # document not visible: drop directly to last frame.
        @_onFrame @_start+@_sprite.duration
      else 
        # adds it to current animations
        _anims.push @

    # **private**
    # frame animator: invokated by the animation loop. If it's time to draw another frame, to it.
    # Otherwise, does nothing
    #
    # @param current [Number] the current timestamp. Null to stop current animation.
    _onFrame: (current) =>
      return unless @_imageSpec?
      # loop until the end of the animation
      if current? and current-@_start < @_sprite.duration
        # only animate at needed frames
        if current-@_start >= (@_step+1)*@_sprite.duration/@_sprite.number
          # changes frame 
          if @_offset.x <= -(@_sprite.number*@_imageSpec.width) 
            @_offset.x = 0 
          else 
            @_offset.x -= @_imageSpec.width

          @_image.css 'background-position': "#{@_offset.x}px #{@_offset.y}px"

          @_step++
          # Slightly move during animation
          if @_newPos?
            @$el.css 
              left: @_newPos.left-@_newPos.stepL*(@_sprite.number-@_step)
              top: @_newPos.top-@_newPos.stepT*(@_sprite.number-@_step)
      else 
        # removes from executing animations first.
        _anims.splice _anims.indexOf(@), 1
        # end of the animation: displays first sprite
        @_offset.x = 0
        @_image.css 'background-position': "#{@_offset.x}px #{@_offset.y}px"

        # if necessary, apply new coordinates and position
        if @_newCoordinates?
          @options.coordinates = @_newCoordinates
          @_newCoordinates = null
        if @_newPos
          delete @_newPos.stepL
          delete @_newPos.stepT
          @$el.css @_newPos
          @_newPos = null


    # **private**
    # Image loading handler: positionnates the widget inside map
    #
    # @param success [Boolean] indicates wheiter or not loading succeeded
    # @param src [String] loaded image source
    # @param img [Image] if successful, loaded image DOM node
    _onLoaded: (success, src, img) =>
      return unless src is "/images/#{@options.source}"
      @unboundFrom rheia.router, 'imageLoaded'
      if success 
        # displays image data and hides alertnative text
        @_image.css 
          background: "url(#{utils.getImageString img})"
          width: @_imageSpec?.width or defaultWidth
          height: @_imageSpec?.height or defaultHeight

        @$el.find('.alt').remove()
      else 
        # displays the alternative text
        @_createAlt()

      @$el.css
        width: @_imageSpec?.width or defaultWidth
        height: @_imageSpec?.height or defaultHeight

      @_positionnate()

      # now display correct sprite
      @_renderSprite()
      @$el.trigger 'loaded', {item:@options.mode}

    # **private**
    # Updates model inner values
    #
    # @param model [Object] new model values
    # @param changes [Object] fields that have changed
    _onUpdate: (model, changes) =>
      @options.model = model
      # removes if map has changed
      return @$el.remove() if @options.model?.map?.id isnt @options.map?.options.mapId

      if 'x' of changes or 'y' of changes
        # positionnate with animation if transition changed
        @_positionnate 'transition' of changes and changes.transition?

      # render new animation if needed
      if 'transition' of changes and changes.transition?
        @_renderSprite()

      if 'imageNum' of changes
        # compute new item image
        @_imageSpec = @options.model.type.images?[@options.model.imageNum] 
        @setOption 'source', @_imageSpec?.file or @options.model.type.descImage


  # widget declaration
  MapItem._declareWidget 'mapItem', $.extend true, {}, $.fn.loadableImage.defaults, 

    # Rendered item
    model: null

    # The associated map
    map: null

    # Disable buttons
    noButtons: true

    # Current position of the widget in map. Read-only: do not change externally
    coordinates: x:null, y:null