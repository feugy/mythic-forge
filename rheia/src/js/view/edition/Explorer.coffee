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
  'underscore'
  'backbone'
  'jquery'
  'i18n!nls/edition'
  'model/ItemType'
], (_, Backbone, $, editionLabels, ItemType) ->

  editionLabels = _.extend {}, editionLabels

  # Create explorer rendering for a given model, relative ot its class
  #
  # @param model [Object] the rendered model
  #
  render = (model, imagesLoader) ->
    # load descriptive image.
    img = model.get 'descImage'
    if img?
      img = "#{conf.baseUrl}/images/#{img}"
      imagesLoader.load img
    "<div data-id=\"#{model.id}\"><img data-src=\"#{img}\"/>#{model.get 'name'}</div>"

  # Displays the explorer on edition perspective
  #
  class Explorer extends Backbone.View

    events: 
      'click dt': '_onToggleCategory'

    # duration of categories animation, in millis
    _openDuration: 250

    # list of displayed categories
    _categories: [{
      name: editionLabels.titles.categories.maps
      id: 'maps'
    },{
      name: editionLabels.titles.categories.fields
      id: 'fieldTypes'
    },{
      name: editionLabels.titles.categories.items
      id: 'itemTypes'
      load: => 
        ItemType.collection.fetch()
    },{
      name: editionLabels.titles.categories.events
      id: 'eventTypes'
    },{
      name: editionLabels.titles.categories.rules
      id: 'rules'
    },{
      name: editionLabels.titles.categories.turnRules
      id: 'turnRules'
    }]

    # The view constructor.
    #
    # @param router [Router] the event bus
    #
    constructor: (@router) ->
      super {tagName: 'div', className:'explorer'}
      ItemType.collection.on 'reset', @_onResetCategory
      @router.on 'imageLoaded', @_onImageLoaded

    # The `render()` method is invoked by backbone to display view content at screen.
    # 
    render: =>
      markup = ''      
      # creates categories
      for category, i in @_categories
        markup += "<dt data-idx=\"#{i}\" class=\"#{category.id}\"><i></i>#{category.name}</dt><dd></dd>"
      @$el.append markup
      @$el.find('dd').hide()

      # for chaining purposes
      return @

    # Open or hides a category. 
    # For categories which have not been opened yet, loads their content.
    #
    # @param evt [Event] the click event
    #
    _onToggleCategory: (evt) =>
      title = $(evt.target).closest('dt')
      # gets the corresponding 
      if title.hasClass 'open'
        title.next('dd').hide @_openDuration, -> title.removeClass 'open'   
      else 
        title.next('dd').show @_openDuration, -> title.addClass 'open'  
        # loads content
        if !title.hasClass 'loaded'
          title.addClass 'loaded'
          console.log "loading category #{@_categories[title.data 'idx'].id}"
          @_categories[title.data 'idx'].load()

    # Image loading handler. Displays image.
    # 
    # @param success [Boolean] true if image loaded, false otherwise
    # @param src [String] original image source url
    # @param data [Object] if success, the image data
    #
    _onImageLoaded: (success, src, data) =>
      return unless success
      @$el.find("img[data-src=#{src}").attr 'src', data

    # Handler invoked when a category have been retrieved
    # Refresh the corresponding display
    #
    # @param collection [Collection] the refreshed collection.
    #
    _onResetCategory: (collection) =>
      selector = null
      switch collection
        when ItemType.collection then selector = 'itemTypes'
      return unless selector?

      container = @$el.find("dt.#{selector} + dd").empty()
      for type in collection.models
        container.append render type, @router.imagesLoader

  return Explorer