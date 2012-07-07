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
  'i18n!nls/edition'
  'model/ItemType'
], (i18n, ItemType) ->

  i18n = _.extend {}, i18n

  # Create explorer rendering for a given model, relative ot its class
  #
  # @param model [Object] the rendered model
  # @param category [Object] the category descriptor for this model
  render = (model, category) ->
    # load descriptive image.
    img = model.get('descImage')
    if img?
      img = "/images/#{img}"
      rheia.imagesService.load(img)
    return """<div data-id="#{model.id}" data-class="#{category.id}" class="#{category.className}">
          <img data-src="#{img}"/>#{model.get 'name'}</div>"""

  # Displays the explorer on edition perspective
  class Explorer extends Backbone.View

    # rendering event mapping
    events: 
      'click dt': '_onToggleCategory'
      'click dd > div': '_onOpenElement'

    # duration of categories animation, in millis
    _openDuration: 250

    # list of displayed categories
    _categories: [{
      name: i18n.titles.categories.maps
      className: 'maps'
      id: 'Map'
    },{
      name: i18n.titles.categories.fields
      className: 'field-types'
      id: 'FieldType'
    },{
      name: i18n.titles.categories.items
      className: 'item-types'
      id: 'ItemType'
      load: => 
        ItemType.collection.fetch()
    },{
      name: i18n.titles.categories.events
      className: 'event-types'
      id: 'EventType'
    },{
      name: i18n.titles.categories.rules
      className: 'rules'
      id: 'Rule'
    },{
      name: i18n.titles.categories.turnRules
      className: 'turn-rules'
      id: 'TurnRule'
    }]

    # The view constructor.
    constructor: () ->
      super({tagName: 'div', className:'explorer'})

      # bind changes to Item types collection
      @bindTo(ItemType.collection, 'reset', @_onResetCategory)
      @bindTo(ItemType.collection, 'add', (element, collection, options) =>
        options.operation = 'add'
        @_onUpdateCategory(element, collection, options))
      @bindTo(ItemType.collection, 'remove', (element, collection, options) =>
        options.operation = 'remove'
        @_onUpdateCategory(element, collection, options))
      @bindTo(ItemType.collection, 'update', (element, collection, options) =>
        options.operation = 'update'
        @_onUpdateCategory(element, collection, options))

      @bindTo(rheia.router, 'imageLoaded', @_onImageLoaded)

    # The `render()` method is invoked by backbone to display view content at screen.
    render: () =>
      markup = ''      
      # creates categories
      for category, i in @_categories
        markup += """<dt data-idx="#{i}">
            <i class="#{category.className}"></i>#{category.name}
          </dt>
          <dd data-id=#{category.id}></dd>"""

      @$el.append(markup)
      @$el.find('dd').hide()

      # for chaining purposes
      return @

    # **private**
    # Open or hides a category. 
    # For categories which have not been opened yet, loads their content.
    #
    # @param evt [Event] the click event
    _onToggleCategory: (evt) =>
      title = $(evt.target).closest('dt')
      # gets the corresponding 
      if title.hasClass 'open'
        title.next('dd').hide(@_openDuration, () -> title.removeClass('open'))   
      else 
        title.next('dd').show(@_openDuration, () -> title.addClass('open') ) 
        # loads content
        if !title.hasClass('loaded')
          title.addClass('loaded')
          category = @_categories[title.data 'idx']
          console.log("loading category #{category.name}")
          if 'load' of category
            category.load()
          else 
            console.error("#{category.name} loading not implemented yet")

    # **private**
    # Open the element clicked by issu ing an event on the bus.
    #
    # @param evt [Event] the click event
    _onOpenElement: (evt) =>
      element = $(evt.target).closest('div')
      id = element.data('id')
      category = element.data('class')
      
      console.log("open element #{id} of category #{category}")
      rheia.router.trigger('open', category, id)

    # **private**
    # Image loading handler. Displays image.
    # 
    # @param success [Boolean] true if image loaded, false otherwise
    # @param src [String] original image source url
    # @param data [Object] if success, the image data
    _onImageLoaded: (success, src, data) =>
      return unless success
      @$el.find("img[data-src='#{src}']").attr('src', data)

    # **private**
    # Handler invoked when a category have been retrieved
    # Refresh the corresponding display
    #
    # @param collection [Collection] the refreshed collection.
    _onResetCategory: (collection) =>
      idx = null
      switch collection
        when ItemType.collection then idx = 2
      return unless idx?

      container = @$el.find("dt[data-idx=#{idx}] + dd").empty()
      for element in collection.models
        container.append(render(element, @_categories[idx]))

    # **private**
    # Handler invoked when a category item have been added or removed
    # Refresh the corresponding display
    #
    # @param element [Object] the category item added or removed
    # @param collection [Collection] the refreshed collection
    # @param options [Object] details on the operation
    # @option options index [Number] index in the collection where the item is added or removed
    # @option options operation [String] 'add', 'remove' or 'update' operation
    _onUpdateCategory: (element, collection, options) =>
      idx = null
      switch collection
        when ItemType.collection then idx = 2
      return unless idx?

      container = @$el.find("dt[data-idx=#{idx}] + dd")
      markup = $(render(element, @_categories[idx]))
      duration = 200
      shift = -250
      add = () =>
        markup.css({x: shift}, duration)
        if options.index is 0
          container.prepend markup
        else 
          container.children().eq(options.index-1).after(markup)
        markup.transition({x:0})

      switch options.operation
        when 'remove' then container.children().eq(options.index).transition({x:shift}, duration, () -> $(this).remove())
        when 'add' then add()
        when 'update' 
          container.children().eq(options.index).remove()
          add()
          
  return Explorer