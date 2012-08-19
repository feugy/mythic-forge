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
  'widget/typeDetails'
], ($, utils, i18n) ->

  # list of displayed categories
  categories = [
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
  ]

  # A tree that displays type models.
  # Organize models in categories.
  # Triggers `open` event when opening a category (with category in parameter)
  # Triggers `click` event when clicking an item (with category and id in parameter)
  TypeTree =
    
    options:  
      # duration of category toggle animations
      animDuration: 250

      # The displayed type models
      content: []

      # when a category is empty, hides it
      hideEmpty: false

      # when first displayed, categories may be opened or not
      openAtStart: false

    # Frees DOM listeners
    destroy: () ->
      @element.off('click')
      $.Widget.prototype.destroy.apply(@, arguments)

    # **private**
    # Builds rendering
    _create: () ->
      @element.on('click', 'dt', (event) => @_onToggleCategory(event))
      @element.on('click', 'dd > div', (event) => @_onOpenElement(event))

      @element.addClass('type-tree').empty()
      # creates categories, and fill with relevant models
      for category in categories
        content = @options.content.filter((model) -> model?._className is category.id or model?.kind is category.id)
        # discard category unless there is content or were told not to do
        continue unless content.length > 0 or !@options.hideEmpty

        categoryClass = utils.dashSeparated(category.id)
        @element.append("""<dt class="#{if @options.openAtStart then 'open' else ''}">
            <i class="#{categoryClass}"></i>#{category.name}
          </dt>
          <dd data-category=#{category.id} class="#{categoryClass}"></dd>""")
        container = @element.find("dd.#{categoryClass}")
        container.hide() unless @options.openAtStart

        $('<div></div>').typeDetails({model:model}).appendTo(container) for model in content 
          
    # **private**
    # Method invoked when the widget options are set. Update rendering if `model` is changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.Widget.prototype._setOption.apply(@, arguments) unless key in ['content']
      switch key
        when 'content' 
          value = [] unless Array.isArray(value)
          @options.content = value
          @_create()

    # **private**
    # Open or hides a category. 
    # Toggle animation, and may trigger the `open` event
    #
    # @param event [Event] the click event
    _onToggleCategory: (event) ->
      title = $(event.target).closest('dt')
      # gets the corresponding 
      if title.hasClass 'open'
        title.next('dd').hide(@options.animDuration, () -> title.removeClass('open'))   
      else 
        title.next('dd').show(@options.animDuration, () -> title.addClass('open')) 
        @_trigger('open', event, title.next('dd').data('category'))

    # **private**
    # Open the element clicked by issu ing an event on the bus.
    #
    # @param event [Event] the click event
    _onOpenElement: (event) ->
      element = $(event.target).closest('div')
      @_trigger('click', event, 
        category: element.data('category')
        id: element.data('id')
      )

  $.widget("rheia.typeTree", $.rheia.baseWidget, TypeTree)