###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
###
'use strict'

define [
  'jquery'
], ($) ->

  class ImagesLoader
        
    # Event bus on which triggering events.
    router: null

    # Temporary stoarage of loading images.
    _pendingImages: {}
    
    # Image local cache
    _cache: {}
    
    # Constructor. 
    #
    # @param router [Events] a backbone event object on which events will be published.
    constructor: (@router) ->
      @router.on 'loadImage', @load

    # Handler invoked when an image finisedh to load. Emit the `imageLoaded` event. 
    #
    # @param event [Event] image loading success event
    _onImageLoaded: (event) =>
      console.debug "Image #{event.target.src} loaded"
      src = event.target.src.replace /\?\d*$/, ''
      # Remove event from pending array
      delete @_pendingImages[src]
      # Gets the image data with a canvas temporary element
      canvas = $("<canvas></canvas>")[0];
      canvas.width = event.target.width;
      canvas.height = event.target.height;
      # Copy the image contents to the canvas
      ctx = canvas.getContext '2d'
      ctx.drawImage event.target, 0, 0;
      data = canvas.toDataURL 'image/png';
      # Store result and emit on the event bus
      @_cache[src] = data;
      @router.trigger 'imageLoaded', true, src, data
  
    # Handler invoked when an image failed loading. Also emit the `imageLoaded` event.
    # @param event [Event] image loading fail event
    _onImageFailed: (event) =>
        console.debug "Image #{event.target.src} failed"
        src = event.target.src.replace /\?\d*$/, ''
        # Remove event from pending array
        delete @_pendingImages[src]
        # Emit an error on the event bus
        @router.trigger 'imageLoaded', false, src
    
    # Load an image. Once it's available, `imageLoaded` event will be emitted on the bus.
    # If this image has already been loaded (url used as key), the event is imediately emitted.
    #
    # @param image [String] the image **ABSOLUTE** url
    # @return true if the image wasn't loaded, false if the cache will be used
    load: (image) =>
      isLoading = false;
      return isLoading unless image?
      # Use cache if available, with a timeout to simulate asynchronous behaviour
      if image of @_cache
        setTimeout =>
          @router.trigger 'imageLoaded', true, image, @_cache[image]
        , 0
      else unless image of @_pendingImages
        console.debug "Loads images #{image}..."
        @_pendingImages[image] = true
        # creates an image facility
        imgData = new Image()
        # bind loading handlers
        $(imgData).load @_onImageLoaded
        $(imgData).error @_onImageFailed
        # adds a timestamped value to avoid browser cache
        imgData.src = "#{image}?#{new Date().getTime()}"
        isLoading = true
      return isLoading

  return ImagesLoader