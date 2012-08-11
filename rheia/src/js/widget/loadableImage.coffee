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
  'i18n!nls/widget'
  'widget/baseWidget'
],  ($, i18n) ->


  # Widget that displays an image and two action buttons to upload a new version or delete the existing one.
  # Triggers a `change`event when necessary.
  LoadableImage = 

    options:    

      # image source: a string url
      # read-only: use `setOption('source')` to modify
      source: null
      
      # **private**
      # the image DOM element
      _image: null

    # Frees DOM listeners
    destroy: () ->
      @element.find('.ui-icon').unbind()
      $.Widget.prototype.destroy.apply(@, arguments)

    # **private**
    # Builds rendering
    _create: () ->
      # encapsulates the image element in a div
      @element.addClass('loadable')
      @options._image = $('<img/>').appendTo(@element)
      # loading handler
      rheia.router.on('imageLoaded', (success, src, img, data) => 
        return unless src is "/images/#{@options.source}"
        @_onLoaded(success, data)
      )
      
      # add action buttons
      $("""<div class="ui-icon ui-icon-folder-open">
            <input type="file" accept="image/*"/>
          </div>""").appendTo(@element).change((event) => @_onUpload(event))

      $('<span class="ui-icon ui-icon-trash">delete</span>')
          .appendTo(@element).click((event) => @_onDelete(event))

      # reload image
      @_createAlt()

      @_setOption('source', @options.source)

    # **private**
    # Method invoked when the widget options are set. Update rendering if `source` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.Widget.prototype._setOption.apply(@, arguments) unless key in ['source']
      switch key
        when 'source' 
          @options.source = value
          # display alternative text
          @_createAlt()
          # load image from images service
          if @options.source is null 
            setTimeout ( => @_onLoaded false), 0
          else 
            rheia.router.trigger('loadImage', "/images/#{@options.source}")

    # **private**
    # Creates an alternative text if necessary
    _createAlt: ->
      return if @element.find('.alt').length isnt 0
      # do not use regular HTML alt attribute because Chrome doesn't handle it correctly: position cannot be set
      @element.prepend("<p class=\"alt\">#{i18n.loadableImage.noImage}</p>")
      
    # **private**
    # Invoked when a file have been choosen.
    # Update the rendering and trigger the `change`event
    # 
    # @param event [Event] click event on the upload action button
    _onUpload: (event) ->
      # Récupère le nom du fichier.
      input = @element.find('input[type=file]')[0]
      # ignore if no file choosen
      return unless input.files.length > 0 
      file = input.files[0]

      # ignore if something else than a image was choosen
      return unless file.type.match('image/*')

      # use a FileReader to load image
      reader = new FileReader()
      reader.onload = (event) =>
        # change the image source
        @options._image.attr('src', event.target.result)
        @element.find('.alt').remove()
      reader.readAsDataURL(file)

      # trigger the change
      @options.source = file
      console.log("change image: #{file}")
      @_trigger('change', event)
    
    # **private**
    # Image loading failure handler: displays the alternative text.
    # If the handler is triggered by the deletion button, emit the `change`event.
    # 
    # @param event [Event]loading failure event or click event.
    _onDelete: (event) ->
      console.log('change image: none')
      # now, displays the alternative text
      @options._image.removeAttr('src')
      @_createAlt()
      @options.source = null
      @_trigger('change', event)
      

    # **private**
    # Image loading handler: hides the alternative text if success, or displays it if error.
    #
    # @param success [Boolean] indicates wheiter or not loading succeeded
    # @param data [String] if successfule, base64 encoded image data.
    _onLoaded: (success, data) ->
      if success 
        # displays image data and hides alertnative text
        @options._image.attr('src', data)
        @element.find('.alt').remove()
      else 
        # displays the alternative text
        @_createAlt()

  $.widget("rheia.loadableImage", $.rheia.baseWidget, LoadableImage)
    