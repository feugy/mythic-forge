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
  'widget/base'
  'widget/typeDetails'
], ($, utils, i18n, Base) ->

  # A tree that displays type models.
  # Organize models in categories.
  # Triggers `open` event when opening a category (with category in parameter)
  # Triggers `openElement` event when clicking an item, or its open contextual menu item (with category and id in parameter)
  # Triggers `removeElement` event when clicking an item remove contextual menu item (with category and id in parameter)
  class TypeTree extends Base
    
    # **private**
    # list of displayed categories
    _categories: [
      name: i18n.titles.categories.clientConfs
      id: 'ClientConf'
    ,
      name: i18n.titles.categories.maps
      id: 'Map'
    ,
      name: i18n.titles.categories.fields
      id: 'FieldType'
    ,
      name: i18n.titles.categories.items
      id: 'ItemType'
    ,
      name: i18n.titles.categories.events
      id: 'EventType'
    ,
      name: i18n.titles.categories.rules
      id: 'Rule'
    ,
      name: i18n.titles.categories.turnRules
      id: 'TurnRule'
    ,
      name: i18n.titles.categories.scripts
      id: 'Script'
    ]

    constructor: (element, options) ->
      super element, options
      @_create()

    # Method invoked when the widget options are set. Update rendering if `model` is changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) =>
      return unless key in ['content']
      switch key
        when 'content' 
          value = [] unless Array.isArray value
          @options.content = value
          @_create()

    # **private**
    # Builds rendering
    _create: =>
      @$el.on 'click', 'dt', @_onToggleCategory
      @$el.on 'click', 'dd > *', @_onOpenElement
      @$el.on 'click', 'dd .menu .open', @_onOpenElement
      @$el.on 'click', 'dd .menu .remove', @_onRemoveElement

      @$el.addClass('type-tree').empty()
      # creates categories, and fill with relevant models
      for category in @_categories
        content = @options.content?.filter (model) -> model?._className is category.id or model?.kind is category.id or model?.kind is null and category.id is 'Script'
        # discard category unless there is content or were told not to do
        continue unless content?.length > 0 or !@options.hideEmpty

        categoryClass = utils.dashSeparated(category.id)
        @$el.append """<dt class="#{if @options.openAtStart then 'open' else ''}">
            <i class="#{categoryClass}"></i>#{category.name}
          </dt>
          <dd data-category=#{category.id} class="#{categoryClass}"></dd>"""
        container = @$el.find "dd.#{categoryClass}"
        container.hide() unless @options.openAtStart

        @_renderModels content, container, category.id
    
    # **private**
    # Render models of a single category. 
    #
    # @param content [Array] models contained in a given category
    # @param container [Object] DOM node that will display the category content
    # @param category [String] the displayed category id
    _renderModels: (content, container, category) =>
      $('<div></div>').typeDetails(model:model).appendTo container for model in content

    # **private**
    # Open or hides a category. 
    # Toggle animation, and may trigger the `open` event
    #
    # @param event [Event] the cancelled click event
    _onToggleCategory: (event) =>
      event?.preventDefault()
      event?.stopImmediatePropagation()
      title = $(event.target).closest 'dt'
      # gets the corresponding 
      if title.hasClass 'open'
        title.next('dd').hide @options.animDuration, -> title.removeClass 'open'   
      else 
        title.next('dd').show @options.animDuration, -> title.addClass 'open' 
        @$el.trigger 'open', title.next('dd').data 'category'

    # **private**
    # Open the element clicked by triggering the `openElement` event.
    #
    # @param event [Event] the cancelled click event
    _onOpenElement: (event) =>
      event?.preventDefault()
      event?.stopImmediatePropagation()
      element = $(event.target).closest 'dd > *'
      return unless element?
      @$el.trigger 'openElement',
        category: element.data 'category'
        id: element.data 'id'

    # **private**
    # Removed the element clicked by triggering the `removeElement` event.
    #
    # @param event [Event] the cancelled click event
    _onRemoveElement: (event) =>
      event?.preventDefault()
      event?.stopImmediatePropagation()
      element = $(event.target).closest 'dd > *'
      return unless element?
      $(event.target).closest('.menu').toggleable 'close'
      @$el.trigger 'removeElement',
        category: element.data 'category'
        id: element.data 'id'

  # widget declaration
  TypeTree._declareWidget 'typeTree', 

    # duration of category toggle animations
    animDuration: 250

    # The displayed type models
    content: []

    # when a category is empty, hides it
    hideEmpty: false

    # when first displayed, categories may be opened or not
    openAtStart: false