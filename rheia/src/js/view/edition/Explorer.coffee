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
  'backbone'
  'utils/utilities'
  'i18n!nls/edition'
  'model/ItemType'
  'model/FieldType'
  'model/Executable'
  'model/Map'
  'widget/Carousel'
], ($, Backbone, utils, i18n, ItemType, FieldType, Executable, Map) ->

  i18n = $.extend {}, i18n

  rootCategory = utils.generateId()

  # Create explorer rendering for a given model, relative ot its class
  #
  # @param model [Object] the rendered model
  # @param category [Object] the category descriptor for this model
  render = (model, category) ->
    name = null

    # load descriptive image.
    img = model.get('descImage')
    if img? and category.id isnt 'FieldType'
      img = "/images/#{img}"
      rheia.imagesService.load(img)

    switch category.id
      when 'ItemType', 'FieldType', 'Map', 'EventType' then name = model.get('name')
      when 'Rule', 'TurnRule' then name = model.id
    rendering = $("""<div data-id="#{model.id}" data-category="#{category.id}" class="#{category.className}">#{name}</div>""")

    # field types uses a carousel instead of an image
    if category.id is 'FieldType'
      $('<div></div>').carousel(
        images: model.get('images')
      ).prependTo(rendering)
    else 
      rendering.prepend("""<img data-src="#{img}"/>""")

    return rendering

  # Computes the sort order of a collection.
  # For executable, group by categories.
  #
  # @param collection [Array] the sorted collection
  # @return a sorted array of models, or an object containing categories and sorted executable inside them
  sortCollection = (collection) ->
    if collection is Executable.collection
      # group by category
      grouped = _(collection.models).groupBy((model) ->
        return model.get('category') || rootCategory
      )
      # sort categories
      grouped = utils.sortAttributes(grouped)
      # sort inside categories
      _(grouped).each((content, group) ->
        grouped[group] = _(content).sortBy((model) -> model.id)
      )
      return grouped
    else
      return _.chain(collection.models).map((model) -> 
        return {sort:model.get('name'), value:model}
      ).sortBy((model) ->
        return model.sort
      ).pluck('value')
      .value()


  # Displays the explorer on edition perspective
  class Explorer extends Backbone.View

    # rendering event mapping
    events: 
      'click dt': '_onToggleCategory'
      'click dd > div': '_onOpenElement'

    # **private**
    # duration of categories animation, in millis
    _animDuration: 250

    # **private**
    # Timeout to avoid multiple refresh of excutable categories
    _changeTimeout: null

    # list of displayed categories
    _categories: [{
      name: i18n.titles.categories.maps
      className: 'maps'
      id: 'Map'
      load: => 
        Map.collection.fetch()
    },{
      name: i18n.titles.categories.fields
      className: 'field-types'
      id: 'FieldType'
      load: => 
        FieldType.collection.fetch()
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
      load: => 
        Executable.collection.fetch()
    },{
      name: i18n.titles.categories.turnRules
      className: 'turn-rules'
      id: 'TurnRule'
    }]

    # The view constructor.
    constructor: () ->
      super({tagName: 'div', className:'explorer'})

      # bind changes to collections
      for model in [ItemType, FieldType, Executable, Map]
        @bindTo(model.collection, 'reset', @_onResetCategory)
        @bindTo(model.collection, 'add', (element, collection) =>
          @_onUpdateCategory(element, collection, null, 'add'))
        @bindTo(model.collection, 'remove', (element, collection) =>
          @_onUpdateCategory(element, collection, null, 'remove'))
        @bindTo(model.collection, 'update', (element, collection, changes) =>
          @_onUpdateCategory(element, collection, changes, 'update'))

      @bindTo(rheia.router, 'imageLoaded', @_onImageLoaded)
      # special case of executable categories that refresh the all tree item
      @bindTo(Executable.collection, 'change:category', @_onCategoryChange)

    # The `render()` method is invoked by backbone to display view content at screen.
    render: () =>
      markup = ''      
      # creates categories
      for category, i in @_categories
        markup += """<dt data-idx="#{i}">
            <i class="#{category.className}"></i>#{category.name}
          </dt>
          <dd data-category=#{category.id} class="#{category.className}"></dd>"""

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
        title.next('dd').hide(@_animDuration, () -> title.removeClass('open'))   
      else 
        title.next('dd').show(@_animDuration, () -> title.addClass('open') ) 
        # loads content
        if !title.hasClass('loaded')
          title.addClass('loaded')
          category = @_categories[title.data('idx')]
          return unless category?
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
      category = element.data('category')
      
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
        when Map.collection then idx = 0
        when FieldType.collection then idx = 1
        when ItemType.collection then idx = 2
        when Executable.collection
          container = @$el.find("dt[data-idx=4] + dd")
          container.hide(@_animDuration, () =>
            container.empty()
            # executable specificity: organize in categories
            grouped = sortCollection(Executable.collection)

            # and then displays
            for category, executables of grouped
              # inside a subcontainer if not in root
              unless category is rootCategory
                container.append("<dt data-subcategory=\"#{category}\">#{category}</dt>")
                catContainer = $('<dd></dd>').hide().appendTo(container) 
              else 
                catContainer = container
              for executable in executables
                catContainer.append(render(executable, @_categories[4]))

            container.show(@_animDuration)
          )

      return unless idx?

      container = @$el.find("dt[data-idx=#{idx}] + dd").empty()
      models = sortCollection(collection)
      for model in models
        container.append(render(model, @_categories[idx]))

    # **private**
    # Handler invoked when a category item have been added or removed
    # Refresh the corresponding display
    #
    # @param element [Object] the category item added or removed
    # @param collection [Collection] the refreshed collection
    # @param changes [Object] map of changed attributes
    # @param operation [String] 'add', 'remove' or 'update' operation
    _onUpdateCategory: (element, collection, changes, operation) =>
      idx = null
      switch collection
        when Map.collection 
          if operation isnt 'update' or '_name' of changes then idx = 0
        when FieldType.collection
          if operation isnt 'update' or '_name' of changes or 'images' of changes then idx = 1
        when ItemType.collection
          if operation isnt 'update' or '_name' of changes or 'descImage' of changes then idx = 2
        when Executable.collection 
          if operation isnt 'update' or '_id' of changes then idx = 4
      return unless idx?

      container = @$el.find("dt[data-idx=#{idx}] + dd")
      markup = render(element, @_categories[idx])
      shift = -250
      add = () =>
        # compute the insertion index
        models = sortCollection(collection)
        if collection is Executable.collection
          category = element.get('category') || rootCategory
          container = @$el.find("dt[data-subcategory=#{element.get('category')}] + dd") unless category is rootCategory
          idx = models[category].indexOf(element)
        else
          idx = models.indexOf(element)

        markup.css({x: shift})
        if idx <= 0
          container.prepend(markup)
        else
          container.children().eq(idx-1).after(markup)
        # use a small delay to avoid animation while inserting into the DOM
        _.delay(() => 
          markup.transition({x:0}, @_animDuration)
        , 10)
        
      switch operation
        when 'remove' then container.find("[data-id=\"#{element.id}\"]").transition({x:shift}, @_animDuration, () -> $(this).remove())
        when 'add' then add()
        when 'update' 
          container.find("[data-id=\"#{element.id}\"]").remove()
          add()
         
    # **private**
    # Refresh the executable content to displays sub-categories, with small delay to avoid too much refresh
    _onCategoryChange: () =>  
      clearTimeout(@_changeTimeout) if @_changeTimeout
      @_changeTimeout = setTimeout(()=>
        @_onResetCategory(Executable.collection)
      , 50)

  return Explorer