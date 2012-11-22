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

  # Widget that displays an image and two action buttons to upload a new version or delete the existing one.
  # Triggers a `change`event when necessary.
  class LoadableImage extends Base
      
    # **private**
    # the image DOM element
    _image: null

    # **private**
    # Builds rendering
    constructor: (element, options) ->
      super element, options
      
      # encapsulates the image element in a div
      @$el.addClass 'loadable'
      @_image = $('<img/>').appendTo @$el
      
      unless @options.noButtons
        # add action buttons
        $("""<div class="ui-icon ui-icon-folder-open">
              <input type="file" accept="image/*"/>
            </div>""").appendTo(@$el).change @_onUpload

        $('<span class="ui-icon ui-icon-trash">delete</span>')
            .appendTo(@$el).click @_onDelete

      # reload image
      @setOption 'source', @options.source

    # Frees DOM listeners
    dispose: =>
      @$el.find('.ui-icon').off()
      super()

    # Method invoked when the widget options are set. Update rendering if `source` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) =>
      return unless key is 'source' 
      @options.source = value
      # do not display alternative text yet
      @_image.removeAttr 'src'
      # load image from images service
      if @options.source is null 
        _.defer => @_onLoaded false, '/images/null'
      else 
        # loading handler
        @bindTo rheia.router, 'imageLoaded', @_onLoaded
        rheia.router.trigger 'loadImage', "/images/#{@options.source}"

    # **private**
    # Creates an alternative text if necessary
    _createAlt: =>
      return if @$el.find('.alt').length isnt 0
      # do not use regular HTML alt attribute because Chrome doesn't handle it correctly: position cannot be set
      @$el.prepend "<p class=\"alt\">#{i18n.loadableImage.noImage}</p>"
      
    # **private**
    # Invoked when a file have been choosen.
    # Update the rendering and trigger the `change`event
    # 
    # @param event [Event] click event on the upload action button
    _onUpload: (event) =>
      # Récupère le nom du fichier.
      input = @$el.find('input[type=file]')[0]
      # ignore if no file choosen
      return unless input.files.length > 0 
      file = input.files[0]

      # ignore if something else than a image was choosen
      return unless file.type.match 'image/*'

      # use a FileReader to load image
      reader = new FileReader()
      reader.onload = (event) =>
        # change the image source
        @_image.attr 'src', event.target.result
        @$el.find('.alt').remove()
      reader.readAsDataURL file

      # trigger the change
      @options.source = file
      @$el.trigger 'change'
    
    # **private**
    # Image loading failure handler: displays the alternative text.
    # If the handler is triggered by the deletion button, emit the `change`event.
    # 
    # @param event [Event]loading failure event or click event.
    _onDelete: (event) =>
      @_image.removeAttr 'src'
      # now, displays the alternative text
      @_createAlt()
      @options.source = null
      @$el.trigger 'change'
      
    # **private**
    # Image loading handler: hides the alternative text if success, or displays it if error.
    #
    # @param success [Boolean] indicates wheiter or not loading succeeded
    # @param src [String] loaded image source
    # @param img [Image] if successful, loaded image DOM node
    _onLoaded: (success, src, img) => 
      return unless src is "/images/#{@options.source}"
      @unboundFrom rheia.router, 'imageLoaded'
      if success 
        # displays image data and hides alertnative text
        @_image.replaceWith $(img).clone()
        @_image = @$el.find 'img'
        @$el.find('.alt').remove()
      else 
        # displays the alternative text
        @_createAlt()

  # widget declaration
  LoadableImage._declareWidget 'loadableImage', 
  
    # image source: a string url
    # read-only: use `setOption('source')` to modify
    source: null

    # allow subclasses to disable buttons
    noButtons: false