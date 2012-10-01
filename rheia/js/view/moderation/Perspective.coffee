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
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

define [
  'jquery'
  'view/TabPerspective'
  'i18n!nls/common'
  'i18n!nls/moderation'
  'text!tpl/moderationPerspective.html'
  'utils/utilities'
  'model/Map'
  'model/Field'
  'model/Item'
  'view/moderation/Item'
  'widget/search'
  'widget/moderationMap'
], ($, TabPerspective, i18n, i18nModeration, template, utils, Map, Field, Item, ItemView) ->

  i18n = $.extend true, i18n, i18nModeration

  # The moderation perspective shows real maps, and handle items, event and players
  class ModerationPerspective extends TabPerspective
    
    # rendering event mapping
    events: 
      'change .maps select': '_onMapSelect'
      'click .toggle-grid': '_onToggleGrid'
      'click .toggle-markers': '_onToggleMarkers'
      'change .zoom': '_onZoomed'

    # **private**
    # View's mustache template
    _template: template

    # **private**
    # search widget
    _searchWidget: null

    # **private**
    # currently displayed map
    _map: null
   
    # **private**
    # map widget
    _mapWidget: null

    # The view constructor.
    constructor: ->
      super 'moderation'

      # bind to global events
      @bindTo Map.collection, 'reset', @_onMapListRetrieved
      @bindTo Map.collection, 'add', @_onMapListRetrieved
      @bindTo Map.collection, 'remove', @_onMapListRetrieved

      # register on fields and items to update map
      @bindTo Field.collection, 'add', @_onAddFieldOrItem
      @bindTo Field.collection, 'remove', @_onRemoveFieldOrItem
      @bindTo Item.collection, 'add', @_onAddFieldOrItem
      @bindTo Item.collection, 'remove', @_onRemoveFieldOrItem

      ###@bindTo rheia.router, 'searchResults', (err, results) =>
        if err?
          # displays an error
          @_searchWidget.setOption 'results', []
          return utils.popup i18n.titles.serverError, _.sprintf(i18n.msgs.searchFailed, err), 'cancel', [text: i18n.buttons.ok]
        @_searchWidget.setOption 'results', results###

      # retrieve map list
      Map.collection.fetch()

    # The `render()` method is invoked by backbone to display view content at screen.
    # Draws the login form.
    render: =>
      super()
      
      # creates a search widget
      @_searchWidget = @$el.find('> .left .search').search(
        #helpTip: i18n.tips.searchTypes
        #search: (event, query) -> rheia.searchService.searchTypes query
        #openElement: (event, details) -> rheia.router.trigger 'open', details.category, details.id
        #removeElement: (event, details) -> rheia.router.trigger 'remove', details.category, details.id
      ).data 'search'

      # instanciate map widget
      @_mapWidget = @$el.find('.map').moderationMap(
        tileDim: 75
        verticalTileNum: 12
        horizontalTileNum: 7
        # use a small zoom, and 0:0 is visible
        zoom: 0.75
        lowerCoord: {x:-3, y:-4}
        displayGrid: true
        displayMarkers: true
        coordChanged: =>
          # reloads map content
          return unless @_map
          @_map.consult @_mapWidget.options.lowerCoord, @_mapWidget.options.upperCoord
        itemClicked: (event, item) =>
          # opens the clicked item
          rheia.router.trigger 'open', 'Item', item.id
      ).data 'moderationMap'

      # bind maps commands
      @$el.find('.toggle-grid').removeAttr 'checked'
      @$el.find('.toggle-grid').attr 'checked', 'checked' if @_mapWidget.options.displayGrid
      @$el.find('.toggle-markers').removeAttr 'checked'
      @$el.find('.toggle-markers').attr 'checked', 'checked' if @_mapWidget.options.displayMarkers
      @$el.find('.zoom').val @_mapWidget.options.zoom

      # for chaining purposes
      @

    # **private**
    # Provide template data for rendering
    #
    # @return an object used as template data
    _getRenderData: =>
      i18n:i18n

    # **private**
    # Delegate method the instanciate a view from a type and an id, either
    # when opening an existing view, or when creating a new one.
    #
    # @param type [String] type of the opened/created instance
    # @param id [String] optional id of the opened instance. Null for creations
    # @return the created view, or null to cancel opening/creation
    _constructView: (type, id) =>
      # creates the relevant view
      view = null
      switch type
        when 'Item' then view = new ItemView id
      view

    # **private**
    # Map selector handler. Gets and displays new selected map content.
    #
    # @param event [Event] select event inside maps selector
    _onMapSelect: (event) =>
      id = $(event.target).val()
      @_map = Map.collection.get id
      # reload map
      @_mapWidget.setOption 'mapId', id
      @_mapWidget.setOption 'lowerCoord', @_mapWidget.options.lowerCoord

    # **private**
    # Empties and fills the map list.
    _onMapListRetrieved: =>
      select = @$el.find '.maps select'
      maps = ''
      for map in Map.collection.models
        maps += "<option value='#{map.id}' #{if map.equals @_map then 'selected="selected"' else ''}>#{map.get 'name'}</option>"
     
      select.empty().append maps

      # select first map if needed
      select.children().first().change() unless @_map?

    # **private**
    # Handler that updates map content when a field or an item is added to collection
    #
    # @param added [Array] array of added items or fields
    _onAddFieldOrItem: (added) =>
      added = [added] unless Array.isArray added
      @_mapWidget?.addData added

    # **private**
    # Handler that updates map content when a field or an item is removed from collection
    #
    # @param removed [Array] array of removed items or fields
    _onRemoveFieldOrItem: (removed) =>
      removed = [removed] unless Array.isArray removed
      @_mapWidget?.removeData removed

    # **private**  
    # Toggle map grid when the corresponding map command is changed.
    # 
    # @param event [Event] click event on the grid checkbox
    _onToggleGrid: (event) =>
      @_mapWidget.setOption 'displayGrid', $(event.target).is ':checked'

    # **private**  
    # Toggle map markers when the corresponding map command is changed.
    # 
    # @param event [Event] click event on the grid checkbox
    _onToggleMarkers: (event) =>
      @_mapWidget.setOption 'displayMarkers', $(event.target).is ':checked'

    # **private**
    # Change the map zoom when the zoom slider command changes.
    #
    # @param event [Event] slider change event
    _onZoomed: (event) =>
      unless @_inhibitZoom
        @_mapWidget.setOption 'zoom', $(event.target).val()
      @_inhibitZoom = false