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
  'utils/validators'
  'model/ItemType'
  'model/EventType'
  'model/Map'
  'model/Field'
  'model/Item'
  'model/Event'
  'model/Player'
  'view/moderation/Item'
  'view/moderation/Event'
  'view/moderation/Player'
  'widget/mapRenderers'
  'widget/search'
  'widget/moderationMap'
  'widget/loadableImage'
], ($, TabPerspective, i18n, i18nModeration, template, utils, validators, ItemType, EventType, 
  Map, Field, Item, Event, Player, ItemView, EventView, PlayerView, Renderers) ->

  i18n = $.extend true, i18n, i18nModeration

  # defaults rendering dimensions
  renderDefaults = 
    hexagon:
      tileDim: 75
      verticalTileNum: 14
      horizontalTileNum: 8
      angle: 45
    diamond:
      tileDim: 75
      verticalTileNum: 11
      horizontalTileNum: 8  
      angle: 45
    square:
      tileDim: 75
      verticalTileNum: 8
      horizontalTileNum: 8
      angle: 0

  # Opens a popup to select instance id.
  # A validator expect to have a value for id.
  # Id unicity is checked on server
  #
  # @param title [String] popup's title
  # @param message [String] popup's message
  # @param check [Function] invoked when user close popup by clicking. 
  # Takes the popup as first argument, and returns false to prevent closing.
  # @param process [Function] invoked when id was validated on server and no error found
  # Takes id as first argument.
  # @return the created popup
  openIdPopup = (title, message, check, process) ->
    popup = utils.popup(title, message, null, [
      text: i18n.buttons.ok
      click: (discard) => 
        return true if discard
        validator.validate()
        # Do not proceed unless no validation error and selected type
        return false unless check(popup) and validator.errors.length is 0
        id = popup.find('.id').val()

        # ask server if id is free
        rid = utils.rid()
        app.sockets.admin.on 'isIdValid-resp', listener = (reqId, err) =>
          return unless rid is reqId
          app.sockets.admin.removeListener 'isIdValid-resp', listener
          return popup.find('.errors').first().empty().append i18n.msgs.alreadyUsedId if err
          validator.dispose()
          # now we can opens the view tab
          popup.dialog 'close'
          popup.off 'click', '.loadable'
          input.off 'keyup'
          process id

        app.sockets.admin.emit 'isIdValid', rid, id
        false
    ]).addClass('choose-type').append """
        <div class="id-container">
          <label>#{i18n.labels.id}#{i18n.labels.fieldSeparator}</label>
          <input type='text' class='id' value='#{utils.generateId()}'/>
        </div>
        <div class='errors'></div>"""
    
    # creates id validator
    validator = new validators.Regexp 
      required: true
      invalidError: i18n.msgs.invalidId
      regexp: i18n.constants.uidRegex
    , i18n.labels.id, input = popup.find('.id'), 'keyup' 

    # displays error on keyup. Binds after validator creation to validate first
    input.focus()
    input.on 'keyup', (event) =>
      # displays error on keyup
      container = popup.find('.errors').first()
      container.empty()
      if validator.errors.length
        container.append error.msg for error in validator.errors

    # returns popup
    popup

  # The moderation perspective shows real maps, and handle items, event and players
  class ModerationPerspective extends TabPerspective
    
    # rendering event mapping
    events: 
      'change .maps select': '_onMapSelect'
      'click .toggle-grid': '_onToggleGrid'
      'click .toggle-markers': '_onToggleMarkers'
      'change .zoom': '_onZoomed'
      'click .embody > .value': '_onDisplayEmbody'

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

    # **private***
    # type selected to create a new item or event
    _creationType: null

    # **private**
    # used to store copied Event/Item and passed as argument to the BaseLinkedView
    _copy: null

    # **private**
    # inhibit zoom handler to avoid looping when updating view rendering
    _inhibitZoom: false
    
    # The view constructor.
    constructor: ->
      super 'moderation'
      @_copy = null

      utils.onRouterReady =>
        # bind to global events
        @bindTo Map.collection, 'reset', @_onMapListRetrieved
        @bindTo Map.collection, 'add', @_onMapListRetrieved
        @bindTo Map.collection, 'remove', @_onMapListRetrieved

        # register on fields and items to update map
        @bindTo Field.collection, 'add', @_onAddFieldOrItem
        @bindTo Field.collection, 'remove', @_onRemoveFieldOrItem
        @bindTo Item.collection, 'add', @_onAddFieldOrItem
        @bindTo Item.collection, 'update', @_onUpdateItem
        @bindTo Item.collection, 'remove', @_onRemoveFieldOrItem
        @bindTo app.router, 'embodyChanged', @_onRefreshEmbodiment
        @bindTo app.router, 'copy', @_onCopy

        @bindTo app.router, 'searchResults', (err, instances, results) =>
          return unless instances is true
          if err?
            # displays an error
            @_searchWidget.setOption 'results', []
            return utils.popup i18n.titles.serverError, _.sprintf(i18n.msgs.searchFailed, err), 'cancel', [text: i18n.buttons.ok]
          @_searchWidget.setOption 'results', results

        # retrieve map list
        Map.collection.fetch()

      # copy hotkey
      $(document).on("keydown.#{@cid}", {keys:'ctrl+shift+c'}, @_onCopyHotKey)

    # The `render()` method is invoked by backbone to display view content at screen.
    # Draws the login form.
    render: =>
      super()
      
      # creates a search widget
      @_searchWidget = @$el.find('> .left .search').search(
        helpTip: i18n.tips.searchInstances
        isType: false,
        dndType: i18n.constants.instanceAffectation
        tooltipFct: utils.instanceTooltip
      ).on('search', (event, query) -> app.searchService.searchInstances query
      ).on('openElement', @_onOpenSearchResult
      ).on('removeElement', (event, details) => 
        app.router.trigger 'remove', details.category, details.id
      ).data 'search'

      # instanciate map widget
      @_mapWidget = @$el.find('.map').moderationMap(
        dndType: i18n.constants.instanceAffectation
        zoom: 0.75
        width: 651
        height: 651
        displayGrid: true
        displayMarkers: true
      ).on('affectInstance', @_onAffect
      ).on('coordChanged', =>
        # reloads map content
        return unless @_map
        @_map.consult @_mapWidget.options.lowerCoord, @_mapWidget.options.upperCoord
      ).on('itemClicked', (event, item) =>
        # opens the clicked item
        app.router.trigger 'open', 'Item', item.id
      ).on('zoomChanged', =>
        @_inhibitZoom = true
        @$el.find('.zoom').val @_mapWidget.options.zoom
      ).data 'moderationMap'

      # bind maps commands
      @$el.find('.toggle-grid').removeAttr 'checked'
      @$el.find('.toggle-grid').attr 'checked', 'checked' if @_mapWidget.options.displayGrid
      @$el.find('.toggle-markers').removeAttr 'checked'
      @$el.find('.toggle-markers').attr 'checked', 'checked' if @_mapWidget.options.displayMarkers
      @$el.find('.zoom').val @_mapWidget.options.zoom

      # bind creation buttons
      @$el.find(".right .new-item").button(
        icons:
          primary: "small new-item"
        text: false
      ).attr('title', i18n.tips.newItem
      ).on 'click', (event) => @_onChooseType event, true

      @$el.find(".right .new-event").button(
        icons:
          primary: "small new-event"
        text: false
      ).attr('title', i18n.tips.newEvent
      ).on 'click', (event) => @_onChooseType event, false

      @$el.find(".right .new-player").button(
        icons:
          primary: "small new-player"
        text: false
      ).attr('title', i18n.tips.newPlayer
      ).on 'click', => @_onOpenElement 'Player'

      @_onRefreshEmbodiment()

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
      return null unless type in ['Item', 'Event', 'Player']
      # creates the relevant view
      view = null
      # generate the proper id
      id = utils.generateId() unless id?
      switch type
        when 'Item'
          if @_creationType?
            view = new ItemView id, new Item type: @_creationType
            @_creationType = null
          else
            view = new ItemView id, @_copy
        when 'Event'
          if @_creationType?
            view = new EventView id, new Event type: @_creationType
            @_creationType = null
          else
            view = new EventView id, @_copy
        when 'Player'
          view = new PlayerView id
      @_copy = null
      view

    # **private**
    # When embodiment changed, refresh its name
    _onRefreshEmbodiment: =>
      @$el.find('.embody > .value').text if app.embodiment? then utils.instanceName(app.embodiment) else i18n.labels.noEmbodiment
      # store new embodiment into local storage for refresh
      

    # **private**
    # Display embodiement's view if possible
    _onDisplayEmbody: =>
      return unless app.embodiment?
      app.router.trigger 'open', 'Item', app.embodiment.id

    # **private**
    # Map selector handler. Gets and displays new selected map content.
    #
    # @param event [Event] select event inside maps selector
    _onMapSelect: (event) =>
      id = $(event.target).val()
      @_map = Map.collection.get id
      # reload map
      @_mapWidget.options[key] = val for key, val of renderDefaults[@_map.kind]
      @_mapWidget.setOption 'renderer', new Renderers[@_map.kind]()
      @_mapWidget.setOption 'tileDim', @_map.tileDim
      @_mapWidget.setOption 'mapId', id
      @_mapWidget.setOption 'lowerCoord', @_mapWidget.options.lowerCoord

    # **private**
    # Empties and fills the map list.
    _onMapListRetrieved: =>
      select = @$el.find '.maps select'
      maps = ''
      found = false
      for map in Map.collection.sortBy 'id'
        found = true if map.equals @_map
        maps += "<option value='#{map.id}' #{if map.equals @_map then 'selected="selected"' else ''}>#{map.id}</option>"
     
      select.empty().append maps

      # select first map if needed
      select.children().first().change() unless found

    # **private**
    # Handler that updates map content when a field or an item is added to collection
    #
    # @param added [Array] array of added items or fields
    _onAddFieldOrItem: (added) =>
      added = [added] unless Array.isArray added
      @_mapWidget?.addData added

    # **private**
    # Handler that updates map content when an item has been changed and need to be displayed
    #
    # @param added [Array] array of added items or fields
    _onUpdateItem: (updated) =>
      # add item to map if map is is equal and map widget do not display yet the item
      if updated?.map?.id is @_mapWidget?.options.mapId and !@_mapWidget?.hasItem updated
        @_mapWidget.addData [updated]

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

    # **private**
    # Display a popup to choose an item type before creating a new item or event
    #
    # @param event [Event] canceled button clic event
    # @param isItem [Boolean] true if selected type is for item, false for event
    _onChooseType: (event, isItem) =>
      event?.preventDefault()

      Class = if isItem then ItemType else EventType
      title = if isItem then i18n.titles.createItem else i18n.titles.createEvent
      message = if isItem then i18n.msgs.chooseItemType else i18n.msgs.chooseEventType

      # display loadable image for each existing types
      listLoaded = =>
        Class.collection.off 'reset', listLoaded
        popup.find('.loader').remove()

        popup.append "<div class='errors'>#{i18n.msgs.noTypes}</div>" if Class.collection.models.length is 0
        # Display a loadable image by types
        for type in Class.collection.models
          $("<div data-id='#{type.id}'></div>").loadableImage(
            source: type.descImage
            noButtons: true
            altText: type.id
          ).appendTo popup

      # gets type list and display popup while.
      Class.collection.on 'reset', listLoaded
      Class.collection.fetch()

      selectLoadable = (event) ->
        popup.find('.loadable').removeClass 'selected'
        $(event.target).closest('.loadable').addClass 'selected'

      popup = openIdPopup title, message, (popup) => 
          # check
          selected = popup.find '.loadable.selected'
          if selected.length is 1
            @_creationType = Class.collection.get selected.data 'id'
            true
          else
            false
        , (id) =>
          # process
          console.log "type #{@_creationType?.id} selected for new object"
          app.router.trigger 'open', (if isItem then 'Item' else 'Event'), id

      popup.addClass('name-choose-popup').
        append("<div class='loader'></div>").
        on('click', '.loadable', selectLoadable).
        on 'dblclick', '.loadable', (event) =>
          selectLoadable event
          # close popup
          popup.parent().find('button').click()

    # **private**
    # Handler invoked when a tab was added to the widget. Make tab draggable to affect instance.
    #
    # @param event [Event] tab additon event
    # @param ui [Object] tab container 
    _onTabAdded: (event, ui) =>
      # superclass behaviour
      super event, ui

      id = $(ui.tab).attr('href').replace '#tabs-', ''
      view = _.find @_views, (view) -> id is view.model.id

      # makes tab draggable
      $(ui.tab).draggable
        scope: i18n.constants.instanceAffectation
        appendTo: 'body'
        distance: 15
        cursorAt: top:-5, left:-5
        drag: -> 
          # do not drag instances if edition in progress
          false if view.canSave()
        helper: -> utils.dragHelper view.model

    # **private**
    # Instance affectation handler.
    # Set the map and coordinate of the instance, and save it.
    # Ignore if dropped instance is not an item.
    #
    # @param event [Event] the drop event on map widget
    # @param details [Object] drop details:
    # @option details instance [Object] the affected instance
    # @option details mapId [String] the new map id
    # @option details coord [Object] x and y coordinates of the drop tile
    _onAffect: (event, details) =>
      # only accepts Items
      return unless details.instance?._className is 'Item'
      map = Map.collection.get details.mapId
      return unless map?
      details.instance.map = map
      details.instance.x = details.coord.x
      details.instance.y = details.coord.y
      # finally, save the instance
      details.instance.save()

    # **private**
    # Opens an event, player or item from the search results
    # First checks that object still exists.
    #
    # @param event [Event] the open event inside search results
    # @param details [Object] opening details:
    # @option details instance [Object] the opened instance class name
    # @option details id [String] the opened instance id
    _onOpenSearchResult: (event, details) => 
      # check object existence first
      obj = require("model/#{details.category}").collection.get details.id
      return app.router.trigger 'open', details.category, details.id if obj?
      # object does not exists anymore
      utils.popup i18n.titles.shadowObj, i18n.msgs.shadowObj, 'warning', [text: i18n.buttons.ok]
      # relaunches search
      @_searchWidget?.triggerSearch true

    # **private**
    # Copy hotkey handler. Opens the copy into a new tab
    #
    # @param event [Event] keyboard event
    _onCopyHotKey: (event) =>
      return unless @$el.is ':visible'
      event?.preventDefault()
      event?.stopImmediatePropagation()
      # tries to save current
      return false unless @_tabs?.options.selected isnt -1
      console.log "#{@className} copy current tab ##{@_tabs.options.selected} by hotkey"
      @_onCopy @_views[@_tabs.options.selected]?.model
      false

    # **private**
    # Copy an Item or an Event. Ask for id with a popup, and opens a new tab.
    #
    # @param event [Event] keyboard event
    _onCopy: (copy) =>
      return unless copy._className in ['Item', 'Event']
      # ask for an id
      type = copy._className
      openIdPopup i18n.titles["copy#{type}"], i18n.msgs.chooseId, (popup) -> 
        true
      , (id) =>
        # Trigger copy
        console.log "copy {@className} #{copy.id} to #{id}"
        @_copy = new copy.constructor copy.toJSON()
        @_copy.id = null
        app.router.trigger 'open', copy._className, id