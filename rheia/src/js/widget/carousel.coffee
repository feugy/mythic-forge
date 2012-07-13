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
###
'use strict'

define [
  'jquery'
  'i18n!nls/widget'
  'widget/BaseWidget'
],  ($, i18n) ->

  # todo parenthesis
  # Displays and navigate along several images, with two nav buttons.
  # One image displayed at a time.
  Carousel =

    options:     
      
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

    # build rendering
    _create: ->
      # creates a container for images, and two navigation buttons
      @element.addClass('carousel').append """
        <div class="previous"></div>
        <div class="mask"><div class="container"></div>
        <div class="next"></div>"""
      # instanciates navigation buttons

      @element.find('.next').button(
          text: false
          disabled: true
        ).click (event) =>
          event.preventDefault()
          @_setCurrent @options.current+1
          false
      @element.find('.previous').button(
          text: false
          disabled: true
        ).click (event) =>
          event.preventDefault()
          @_setCurrent @options.current-1
          false
      
      # first displayal
      @_displayImages @options.images

    # **private**
    # Updates the current displayed image, with navigation animation.
    # Checks before the index validity in the `images` array. 
    # Updates the nav button state.
    # `change` event is possibly triggered.
    #
    # @param value [Number] new image index.
    _setCurrent: (value) ->
      # first check the value
      return unless value >= 0 and value < @options.images.length
      
      # compute the image width for moves
      imageWidth = @element.find('.imagesContainer img').outerWidth true

      # set the container total width, in case it hasn't enought space to display
      @element.find('.imagesContainer').width imageWidth*@options.images.length
          
      # moves the image container
      @element.find('.imagesContainer').stop().animate
          left : -imageWidth * value
        , @options.speed

      # updates nav buttons.
      @element.find('.previous').button 'option', 'disabled', value is 0
      @element.find('.next').button 'option', 'disabled', value is @options.images.length-1
      
      # if we modified the index
      if value isnt @options.current
        # updates it and triggers event
        @options.current = value
        @_trigger 'change'
      
    # **private**
    # Removes current images and displays the new image array.
    # Tries to keep the current position.
    #
    # @param images [Array<String>] the new image array (contains url strings)
    _displayImages: (images) ->
      # removes previous images
      @element.find('.imagesContainer td').remove()
      @options.images = if Array.isArray(images) then images else []

      # displays new ones
      container = @element.find('.imagesContainer')
      container.append """<img class="#{@options.imageClass}" src="#{image}?#{new Date().getTime()}"/>""" for image in @options.images
        
      # try to keep the current position
      if @options.current < images.length
        @_setCurrent @options.current
      else
        @_setCurrent 0

    # **private**
    # Method invoked when the widget options are set. Update rendering if `current` or `images` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.Widget.prototype._setOption.apply @, arguments unless key in ['current', 'images']
      switch key
        when 'current' then @_setCurrent value
        when 'images' then @_displayImages value


  $.widget "rheia.carousel", $.rheia.baseWidget, Carousel