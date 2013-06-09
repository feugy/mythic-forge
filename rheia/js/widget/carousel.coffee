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

  # Displays and navigate along several images, with two nav buttons.
  # One image displayed at a time.
  class Carousel extends Base

    # builds rendering
    constructor: (element, options) ->
      super element, options
      
      # creates a container for images, and two navigation buttons
      @$el.addClass('carousel').append """
        <div class="previous"></div>
        <div class="mask"><div class="container"></div></div>
        <div class="next"></div>"""
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

      # loading handler
      @bindTo app.router, 'imageLoaded', (success, src, image) => 
        img = _(@options.images).find (source) -> _(src).endsWith source
        return unless img?
        @$el.find("img[data-src='#{img}']").attr('src', image).removeData('src').addClass @options.imageClass

      # first displayal, when dom is attached
      _.defer => @_displayImages @options.images

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
    # Updates the current displayed image, with navigation animation.
    # Checks before the index validity in the `images` array. 
    # Updates the nav button state.
    # `change` event is possibly triggered.
    #
    # @param value [Number] new image index.
    _setCurrent: (value, animate=false) =>
      # first check the value
      return unless value >= 0 and value < @options.images.length
      container = @$el.find '.container'

      # compute the image width for moves: we need to be attached to body
      imageWidth = container.children().outerWidth true

      # set the container total width, in case it hasn't enought space to display
      container.width imageWidth*@options.images.length
        
      # moves the image container
      container.stop()
      offset = -imageWidth * value
      if animate
        container.animate {left: offset}, @options.speed
      else
        container.css left: offset

      # updates nav buttons.
      @$el.find('.previous').button 'option', 'disabled', value is 0
      @$el.find('.next').button 'option', 'disabled', value is @options.images.length-1
      
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
      @$el.find('.container').empty()
      @options.images = if Array.isArray images then images else []

      # displays new ones
      container = @$el.find '.container'
      for image in @options.images
        container.append """<img class="#{@options.imageClass}" data-src="#{image}"/>"""
        app.router.trigger 'loadImage', "/images/#{image}" if image isnt null 

      # try to keep the current position
      if @options.current < images.length
        @_setCurrent @options.current
      else
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