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

  defaultHeight = 75
  defaultWidth = 75

  # List of executing animations
  _anims = {}

  # The unic animation loop
  _loop = (time) ->
    # request another animation frame for next rendering.
    window.requestAnimationFrame _loop 
    if document.hidden
      # if document is in background, animations will stop, so stop animations.
      time = null
    # trigger onFrame for each executing animations
    for id, anim of _anims
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

    # **private**
    # number of image sprites
    _numSprites: 1

    # **private**
    # number of steps of the longuest sprite
    _longestSprite: 0
    
    # **private**
    # flag to indicate wether to reload image after animation
    _reloadAfterAnimation: false

    # Builds rendering. Image is computed from the model type image and instance number
    constructor: (element, options) ->
      @_sprite = null
      @_step = 0
      @_offset = x:0, y:0
      @_start = null
      @_newCoordinates = null
      @_newPos = null
      @_reloadAfterAnimation = false
      # load current image
      @_setImageSpec options
      super element, options

      @$el.addClass 'map-item'

      @_image.replaceWith '<div class="image"></div>'
      @_image = @$el.find '.image'

      # bind to model events
      unless options.noUpdate
        @bindTo @options.model, 'update',  @_onUpdate
        @bindTo @options.model, 'destroy', => @$el.remove()

    # **private**
    # On image spec changes, compute number of sprites and longest sprite
    # Also set the option 'source' that reloads item image, unless reload is false
    # 
    # @param options [Object] option to modify, or this.options if null
    _setImageSpec: (options = null) =>
      opts = options or @options
      @_imageSpec = opts.model.type.images?[opts.model.imageNum]
      @_numSprites = 1
      @_longestSprite = 1
      if @_imageSpec?.sprites?
        @_numSprites = _.keys(@_imageSpec.sprites).length
        for name, sprite of @_imageSpec.sprites when sprite.number > @_longestSprite
          @_longestSprite = sprite.number

      value = @_imageSpec?.file or opts.model.type.descImage
      unless options?
        @setOption 'source', value
      else
        opts.source = value

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
      pos.left += o.renderer.tileW*(1-@_imageSpec.width)/2 
      pos.top += o.renderer.tileH*(1-@_imageSpec.height)

      if defer 
        # do not apply immediately the new position
        @_newCoordinates = coordinates
        @_newPos = pos
      else
        @options.coordinates = coordinates
        @$el.css pos

    # **private**
    # Shows relevant sprite image regarding the current model animation and current timing
    #
    # @param reload [Boolean] trigger reload at animation end
    _renderSprite: (reload=false) =>
      return unless @_imageSpec?
      @_reloadAfterAnimation = reload
      
      # do we have a transition ?
      transition = @options.model.getTransition()
      transition = null unless @_imageSpec.sprites? and transition of @_imageSpec.sprites

      # gets the item sprite's details.
      if transition? and 'object' is utils.type @_imageSpec.sprites
        @_sprite = @_imageSpec.sprites[transition]
      else
        @_sprite = null

      @_step = 0
      # set the sprite row
      @_offset.x = 0
      @_offset.y = if @_sprite? then -@_sprite.rank / 100*@_numSprites else 0

      # no: just display the sprite image
      @_image.css backgroundPosition: "#{@_offset.x}% #{@_offset.y}%"
      return @_onLastFrame() unless transition?

      # yes: let's start the animation !
      @_start = new Date().getTime()

      # if we moved, compute the steps
      if @_newPos?
        @_newPos.stepL = (@_newPos.left-parseInt @$el.css 'left')/@_sprite?.number
        @_newPos.stepT = (@_newPos.top-parseInt @$el.css 'top')/@_sprite?.number

      if document.hidden
        # document not visible: drop directly to last frame.
        @_onLastFrame()
      else 
        # adds it to current animations
        _anims[@options.model.id] = @

    # **private**
    # frame animator: invokated by the animation loop. If it's time to draw another frame, to it.
    # Otherwise, does nothing
    #
    # @param current [Number] the current timestamp. Null to stop current animation.
    _onFrame: (current) =>
      return unless @_imageSpec? and @_sprite?
      # loop until the end of the animation
      if current? and current-@_start < @_sprite.duration
        # only animate at needed frames
        if current-@_start >= (@_step+1)*@_sprite.duration/(@_sprite.number+1)
          # changes frame 
          @_offset.x = @_step%@_sprite.number*-100

          @_image.css backgroundPosition: "#{@_offset.x}% #{@_offset.y}%"
          # Slightly move during animation
          if @_newPos?
            @$el.css 
              left: @_newPos.left-@_newPos.stepL*(@_sprite.number-@_step)
              top: @_newPos.top-@_newPos.stepT*(@_sprite.number-@_step)

          @_step++
      else 
        @_onLastFrame()

    # ** private**
    # Apply last frame: display sprite's first position, end movement
    _onLastFrame: =>
      # removes from executing animations first.
      delete _anims[@options.model.id]

      # if necessary, apply new coordinates and position
      if @_newCoordinates?
        @options.coordinates = @_newCoordinates
        @_newCoordinates = null
      if @_newPos
        delete @_newPos.stepL
        delete @_newPos.stepT
        @$el.css @_newPos
        @_newPos = null

      @_offset.x = 0
      # reloads if necessary
      if @_reloadAfterAnimation
        @_reloadAfterAnimation = false
        @_setImageSpec()
      else
        # end of the animation: displays first sprite
        @$el.css backgroundPosition: "#{@_offset.x}% #{@_offset.y}%"

    # **private**
    # Image loading handler: positionnates the widget inside map
    #
    # @param success [Boolean] indicates wheiter or not loading succeeded
    # @param src [String] loaded image source
    # @param img [Image] if successful, loaded image DOM node
    _onLoaded: (success, src, img) =>
      return unless src is "/images/#{@options.source}"
      @unboundFrom app.router, 'imageLoaded'
      if success 
        # displays image data and hides alternative text
        # As it was already loaded, browser cache will be involved
        @_image.css background: "url(#{img})"

        @$el.find('.alt').remove()
      else 
        # displays the alternative text
        @_createAlt()

      @$el.css
        width: @options.map?.options.renderer.tileW*@_imageSpec?.width
        height: @options.map?.options.renderer.tileH*@_imageSpec?.height

      @_image.css backgroundSize: "#{100*@_longestSprite}% #{100*@_numSprites}%"

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
      return @$el.remove() if @options.map? and @options.model?.map?.id isnt @options.map.options.mapId

      if ('x' of changes or 'y' of changes) and @options.map?
        # positionnate with animation if transition changed
        @_positionnate 'transition' of changes and changes.transition?

      needsReload = 'imageNum' in changes
      # render new animation if needed
      if 'transition' of changes and changes.transition? and @options.map?
        @_renderSprite needsReload
      else if needsReload
        # renderSprite will reload if necessary
        @_setImageSpec()


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

    # Indicate whether or not this widget should update himself when the underluying model is updated
    noUpdate: false