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
  'widget/loadableImage'
],  ($) ->


  # Widget that renders an item inside a map Item.
  # Manage its position and its animations
  # triggers an `clicked` event with model as attribute when clicked
  $.widget 'rheia.mapItem', $.rheia.loadableImage, 

    options:    

      # Rendered item
      model: null

      # the associated map
      map: null

      # disable buttons
      noButtons: true

      # current position of the widget in map. Read-only: do not change externally
      coordinates: x:null, y:null

    # **private**
    # model image specification
    _imageSpec: null

    # Frees DOM listeners
    destroy: ->
      @element.off()
      $.rheia.loadableImage::destroy.apply @, arguments
      @element.remove()

    # **private**
    # Builds rendering. Image is computed from the model type image and instance number
    _create: ->
      # compute item image
      @_imageSpec = @options.model.get('type').get('images')?[@options.model.get 'imageNum']
      @options.source = @_imageSpec?.file
      $.rheia.loadableImage::_create.apply @, arguments

      @element.addClass 'map-item'
      @element.on 'click', (event) =>
        @_trigger 'clicked', event, @options.model

      # bind to model events
      @bindTo @options.model, 'update', (model) => @_onUpdate model
      @bindTo @options.model, 'destroy', => @_onDestroy

    # **private**
    # Places the current widget indise the map widget.
    # Will be ineffective if position has not changed
    _positionnate: ->
      # compute new position, and returns if equal to current position
      coordinates =
        x: @options.model.get 'x'
        y: @options.model.get 'y'
      return unless coordinates.x isnt @options.coordinates.x or coordinates.y isnt @options.coordinates.y
      @options.coordinates = coordinates

      # get the widget cell coordinates
      pos = @options.map.elementOffset @options.coordinates

      zoom = @options.map.options.zoom
      
      # center horizontally with tile, and make tile bottom and widget bottom equal
      size = @options.map.tileSize()
      pos.left += (size.width-@_imageSpec.width*zoom)/2 
      pos.top += size.height-@_imageSpec.height*zoom

      # add perspectivve correction TODO iso specific
      correction = -0.75*(@options.model.get('x')-@options.map.options.lowerCoord.x)+4
      pos['-moz-transform'] = "skewX(#{correction}deg) scale(#{zoom})"
      pos['-webkit-transform'] = "skewX(#{correction}deg) scale(#{zoom})"
      @element.css pos

    # **private**
    # Shows relevant sprite image regarding the current model animation and current timing
    _renderSprite: ->
      #TODO
      offsetX = 0
      offsetY = 0
      @_image.css 'background-position': "#{offsetX}px #{offsetY}px"

    # **private**
    # Image loading handler: positionnates the widget inside map
    #
    # @param success [Boolean] indicates wheiter or not loading succeeded
    # @param src [String] loaded image source
    # @param img [Image] if successful, loaded image DOM node
    _onLoaded: (success, src, img) ->
      $.rheia.loadableImage::_onLoaded.apply @, arguments
      return unless src is "/images/#{@options.source}"
      
      @element.css
        width: @_imageSpec.width
        height: @_imageSpec.height

      @_positionnate()

      # now display correct sprite
      @_renderSprite()
      @_trigger 'loaded', null, {item:@options.mode}

    # **private**
    # Updates model inner values
    #
    # @param model [Object] new model values
    _onUpdate: (model) ->
      @options.model = model
      # removes if map has changed
      @_onDestroy() if @options.model?.get('map')?._id isnt @options.map.options.mapId

      # potential move 
      @_positionnate()

    # **private**
    # On model destruction, destroy the widget also
    _onDestroy: ->
      @destroy()
