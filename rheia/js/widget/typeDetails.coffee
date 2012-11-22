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
  'i18n!nls/widget'
  'widget/base'
  'widget/carousel'
  'widget/toggleable'
], ($, utils, i18n, i18nWidget, Base) ->

  i18n = $.extend true, i18n, i18nWidget

  # This widget renders a type model to be displayed in explorer.
  # Draws the type image for EventType and ItemType, use a carousel for FieldType, and displays 
  # just name for others
  # Displays a contextual menu, but handlers are difined by typeTree widget.
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
      img = @options.model.get 'descImage'
      if img? and category isnt 'FieldType'
        @_pendingImage = "/images/#{img}"
        @bindTo rheia.router, 'imageLoaded', => @_onImageLoaded.apply @, arguments
        rheia.imagesService.load @_pendingImage

      switch category
        when 'ItemType', 'FieldType', 'Map', 'EventType' then name = @options.model.get 'name'
        when 'Executable' 
          name = @options.model.get 'name'
          # for opening behaviour, when need to distinguish Rules from TurnRules
          category = @options.model.kind
          categoryClass = utils.dashSeparated category

      @$el.addClass(@options.model.id)
        .data('id', @options.model.id)
        .data('category', category)
        .addClass(categoryClass)
        .text name

      # field types uses a carousel instead of an image
      if category is 'FieldType'
        $('<div></div>').carousel(
          images: @options.model.get 'images'
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
        @$el.toggleClass 'inactive', !@options.model.get 'active' if category in ['TurnRule', 'Rule']

      # adds a contextual menu that opens on right click
      @_menu = $("""<ul class="menu">
          <li class="open"><i class="x-small ui-icon open"></i>#{_.sprintf i18n.typeDetails.open, name}</li>
          <li class="remove"><i class="x-small ui-icon remove"></i>#{_.sprintf i18n.typeDetails.remove, name}</li>
        </ul>""").toggleable().appendTo(@$el).data 'toggleable'

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
      @unboundFrom rheia.router, 'imageLoaded'
      @$el.find("img").replaceWith $(img).clone() if success

  # widget declaration
  TypeDetails._declareWidget 'typeDetails', 

    # The displayed type model
    model: null
