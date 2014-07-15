###
  Copyright 2010~2014 Damien Feugas

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
  'i18n!nls/widget'
  'widget/base'
  'widget/carousel'
  'widget/toggleable'
], ($, utils, i18n, i18nWidget, Base) ->

  i18n = $.extend true, i18n, i18nWidget

  # This widget renders a type model to be displayed in explorer.
  # Draws the type image for EventType and ItemType, use a carousel for FieldType, and displays 
  # just name for others
  # Displays a contextual menu, but handlers are defined by typeTree widget.
  class TypeDetails extends Base

    # **private**
    # pending image source
    _pendingImage: null

    # **private**
    # contextual menu
    _menu: null

    # Builds rendering
    constructor: (element, options) ->
      super element, options
      
      @$el.addClass('type-details').empty()
      name = null
      category = @options.model._className
      categoryClass = utils.dashSeparated category

      # load descriptive image.
      img = @options.model.descImage
      if img? and category isnt 'FieldType'
        @_pendingImage = "/images/#{img}"
        @bindTo app.router, 'imageLoaded', => @_onImageLoaded.apply @, arguments
        app.imagesService.load @_pendingImage

      switch category
        when 'ItemType', 'FieldType', 'Map', 'EventType', 'ClientConf' then name = @options.model.id
        when 'Executable' 
          name = @options.model.id
          # for opening behaviour, when need to distinguish Rules from TurnRules
          category = @options.model.meta.kind
          categoryClass = utils.dashSeparated category

      @$el.addClass(@options.model.id)
        .data('id', @options.model.id)
        .data('category', category)
        .addClass(categoryClass)
        .text name

      # field types uses a carousel instead of an image
      if category is 'FieldType'
        $('<div></div>').carousel(
          images: @options.model.images
        ).prependTo @$el

        @$el.draggable(
          scope: i18n.constants.fieldAffectation
          appendTo: 'body'
          cursorAt: top:-5, left:-5
          helper: (event) ->
            carousel = $(event.target).closest('.type-details').find '.carousel'
            # extract the current displayed image from the carousel
            idx = carousel.data('carousel').options.current
            dragged = carousel.find("img:nth-child(#{idx+1})").clone()
            # add informations on the dragged field
            dragged.data 'idx', idx
            dragged.data 'id', carousel.closest(".#{categoryClass}").data 'id'
            dragged.addClass 'dragged'
            dragged
        )
      else
        @$el.prepend "<img/>" if category in ['ItemType', 'EventType']
        if category in ['TurnRule', 'Rule']
          @$el.addClass 'inactive' unless @options.model.meta.active

      # adds a contextual menu that opens on right click
      content = "<ul class='menu'><li class='open'><i class='x-small ui-icon open'></i>#{_.sprintf i18n.typeDetails.open, name}</li>"

      # specific case of default client configuration that cannot be removed
      if category isnt 'ClientConf' or @options.model.id isnt 'default'
        content += "<li class='remove'><i class='x-small ui-icon remove'></i>#{_.sprintf i18n.typeDetails.remove, name}</li>"

      content += '</ul>'
      
      @_menu = $(content).toggleable().appendTo(@$el).data 'toggleable'

      @$el.on 'contextmenu', (event) =>
        event?.preventDefault()
        event?.stopImmediatePropagation()
        @_menu.open event?.pageX, event?.pageY
          
    # **private**
    # Method invoked when the widget options are set. Update rendering if `model` is changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) =>
      return unless key in ['model']
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
    _onImageLoaded: (success, src, img) =>
      return unless @_pendingImage is src
      @unboundFrom app.router, 'imageLoaded'
      @$el.find("img").attr 'src', img if success

  # widget declaration
  TypeDetails._declareWidget 'typeDetails', 

    # The displayed type model
    model: null
