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
  'underscore'
  'i18n!nls/widget'
  'widget/base'
],  ($, _, i18n, Base) ->

  sum = (array) ->
    _.reduce array, ((sum, val) -> sum + (val or 0)), 0

  # Displays and navigate along several images, with two nav buttons.
  # One image displayed at a time.
  class Carousel extends Base

    # **private**
    # how many image are still loading
    _pending: 0

    # **private**
    # link to image container
    _container: null

    # builds rendering
    constructor: (element, options) ->
      super element, options

      # creates a container for images, and two navigation buttons
      @$el.addClass('carousel').append """
        <div class="previous"></div>
        <div class="mask"><div class="container"></div></div>
        <div class="next"></div>"""
      @_container = @$el.find '.container'

      # instanciates navigation buttons
      @$el.find('.next').button(
          text: false
          disabled: true
        ).click (event) =>
          event.preventDefault()
          event.stopImmediatePropagation()
          @_setCurrent @options.current+1, true

      @$el.find('.previous').button(
          text: false
          disabled: true
        ).click (event) =>
          event.preventDefault()
          event.stopImmediatePropagation()
          @_setCurrent @options.current-1, true

      # first displayal
      @_displayImages @options.images

    # Method invoked when the widget options are set. Update rendering if `current` or `images` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) =>
      return unless key in ['current', 'images']
      switch key
        when 'current' then @_setCurrent value
        when 'images' then @_displayImages value

    # **private**
    # image loading handler
    # @param success [Boolean] true if image was loaded
    # @param src [String] image URI
    # @param image [Object] image data
    _onImageLoaded: (success, src, image) => 
      img = _.find @options.images, (source) -> _(src).endsWith source
      idx = _.indexOf @options.images, img
      return unless img?
      @_pending--

      node = @_container.children ":eq(#{idx})"

      node.attr('src', image).addClass @options.imageClass

      # last image loaded ?
      if @_pending is 0
        # unbound from loader
        @unboundFrom app.router, 'imageLoaded'
        
        # try to keep the current position
        if @options.current < @options.images.length
          @_setCurrent @options.current
        else
          @_setCurrent 0


    # **private**
    # Updates the current displayed image, with navigation animation.
    # Checks before the index validity in the `images` array. 
    # Updates the nav button state.
    # `change` event is possibly triggered.
    #
    # @param value [Number] new image index.
    _setCurrent: (value, animate=false) =>
      # first check the value
      return unless value >= 0 and value < @options.images.length
      # updates nav buttons.
      @$el.find('.previous').button 'option', 'disabled', value is 0
      @$el.find('.next').button 'option', 'disabled', value is @options.images.length-1
      
      # moves the image container
      @_container.stop()
      # compute offset needed
      children = @_container.children()
      offset = 0
      for img, idx in @options.images when idx < value
        offset -= $(children[0]).outerWidth true

      if animate
        @_container.animate {left: offset}, @options.speed
      else
        @_container.css left: offset

      # if we modified the index
      if value isnt @options.current
        # updates it and triggers event
        @options.current = value
        @$el.trigger 'change'
      
    # **private**
    # Removes current images and displays the new image array.
    # Tries to keep the current position.
    #
    # @param images [Array<String>] the new image array (contains url strings)
    _displayImages: (images) =>
      # removes previous images
      @_container.empty()
      @options.images = if Array.isArray images then images else []

      @_pending = @options.images.length
      if @_pending > 0
        # loading handler
        @bindTo app.router, 'imageLoaded', @_onImageLoaded
        # displays new ones
        for image in @options.images
          @_container.append """<img class="#{@options.imageClass}"/>"""
          app.router.trigger 'loadImage', "/images/#{image}" if image isnt null 
      else
        # no images to display: set current to 0
        @_setCurrent 0

  # widget declaration
  Carousel._declareWidget 'carousel', 
      
    # displayed images. An array of images urls.
    # read-only: use `setOption('images')` to modify
    images: []
    
    # current displayed image index.
    # read-only: use `setOption('current')` to modify
    current: 0
    
    # navigation animation speed, in millis.
    speed: 300,
    
    # Css class added to images.
    imageClass: 'thumbnail'