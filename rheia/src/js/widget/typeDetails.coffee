###
  Copyright 2010,2011,2012 Damien Feugas

    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http:#www.gnu.org/licenses/>.
###
'use strict'

define [
  'jquery'
  'utils/utilities'
  'i18n!nls/common'
  'widget/baseWidget'
  'widget/Carousel'
], ($, utils, i18n) ->

  # This widget renders a type model to be displayed in explorer.
  # Draws the type image for EventType and ItemType, use a carousel for FieldType, and displays 
  # just name for others
  TypeDetails =
    
    options:  
      # The displayed type model
      model: null

    # **private**
    # For unbind purposes
    _loadCallback: null

    # **private**
    # pending image source
    _pendingImage: null

    # Frees DOM listeners
    destroy: () ->
      rheia.router.off('imageLoaded', @_loadCallback) if @_loadCallback?
      $.Widget.prototype.destroy.apply(@, arguments)

    # **private**
    # Builds rendering
    _create: () ->
      @element.addClass('type-details').empty()
      name = null
      category = @options.model._className
      categoryClass = utils.dashSeparated(category)

      # load descriptive image.
      img = @options.model.get('descImage')
      if img? and category.id isnt 'FieldType'
        @_pendingImage = "/images/#{img}"
        @_loadCallback = (success, src, img, data) =>
          @_onImageLoaded(success, src, img, data)
        rheia.router.on('imageLoaded', @_loadCallback)
        rheia.imagesService.load(@_pendingImage)

      switch category
        when 'ItemType', 'FieldType', 'Map', 'EventType' then name = @options.model.get('name')
        when 'Executable' 
          name = @options.model.id
          # for opening behaviour, when need to distinguish Rules from TurnRules
          category = @options.model.kind
          categoryClass = utils.dashSeparated(category)

      @element.addClass(@options.model.id)
        .data('id', @options.model.id)
        .data('category', category)
        .addClass(categoryClass)
        .text(name)

      # field types uses a carousel instead of an image
      if category is 'FieldType'
        $('<div></div>').carousel(
          images: @options.model.get('images')
        ).draggable(
          scope: i18n.constants.fieldAffectation,
          appendTo: 'body',
          cursorAt: {top:-5, left:-5},
          helper: (event) ->
            carousel = $(this)
            # extract the current displayed image from the carousel
            idx = carousel.data('carousel').options.current
            dragged = carousel.find("img:nth-child(#{idx+1})").clone()
            # add informations on the dragged field
            dragged.data('idx', idx)
            dragged.data('id', carousel.closest(".#{categoryClass}").data('id'))
            dragged.addClass('dragged')
            return dragged
        ).prependTo(@element)
      else
        @element.prepend("""<img/>""") if category in ['ItemType', 'EventType']
        @element.toggleClass('inactive', !@options.model.get('active')) if category in ['TurnRule', 'Rule']
          
    # **private**
    # Method invoked when the widget options are set. Update rendering if `model` is changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.Widget.prototype._setOption.apply(@, arguments) unless key in ['model']
      switch key
        when 'model' 
          @options.model = value
          @_create()


    # **private**
    # Image loading handler. Displays image.
    # 
    # @param success [Boolean] true if image loaded, false otherwise
    # @param src [String] original image source url
    # @param img [Image] an Image object, null in case of failure
    # @param data [String] the image base 64 encoded string, null in case of failure
    _onImageLoaded: (success, src, img, data) ->
      return unless @_pendingImage is src
      rheia.router.off('imageLoaded', @_loadCallback)
      @_loadCallback = null
      @element.find("img").attr('src', data) if success

  $.widget("rheia.typeDetails", $.rheia.baseWidget, TypeDetails)