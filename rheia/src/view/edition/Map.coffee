###
  Copyright 2010~2014 Damien Feugas
  
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
  'underscore'
  'i18n!nls/common'
  'i18n!nls/edition'
  'text!tpl/editionMap.html'
  'view/BaseEditionView'
  'model/Map'
  'model/Field'
  'model/FieldType'
  'widget/mapRenderers'
  'widget/authoringMap'
], ($, _, i18n, i18nEdition, template, BaseEditionView, Map, Field, FieldType, Renderers) ->

  i18n = $.extend true, i18n, i18nEdition

  # Displays and edit a map on edition perspective
  class MapView extends BaseEditionView

    # map view events to methods
    events: 
      'click .toggle-grid': '_onToggleGrid'
      'click .toggle-markers': '_onToggleMarkers'
      'change .zoom': '_onZoomed'

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: Map.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeMapConfirm

    # **private**
    # map kind rendering
    _kindWidget: null

    # **private**
    # map content widget
    _mapWidget: null

    # **private**
    # tile dimension widget
    _tileDimWidget: null

    # **private**
    # action button for selection removal
    _removeSelectionButton: null

    # **private**
    # ordered array that stores field type image numbers during a multiple affectation
    _selectedImages: []

    # **private**
    # inhibit zoom handler to avoid looping when updating view rendering
    _inhibitZoom: false

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id) ->
      super id, 'map'
      # register on fields modification to update map displayal
      @bindTo Field.collection, 'add', (added) =>
        return unless @_mapWidget? and added.mapId is @model.id
        added = [added] unless Array.isArray added
        added[i] = obj.toJSON() for obj, i in added
        @_mapWidget.addData added

      @bindTo Field.collection, 'remove', (removed) =>
        return unless @_mapWidget? and removed.mapId is @model.id
        removed = [removed] unless Array.isArray removed
        removed[i] = obj.toJSON() for obj, i in removed
        @_mapWidget.removeData removed

      @_refreshTileDim = _.debounce @_refreshTileDim, 150

      console.log "creates map edition view for #{@model.id}"

    # Extends inherited method to add button for selection removal
    #
    # @return the action bar rendering.
    getActionBar: =>
      bar = super()
      # adds specific buttons
      if bar.find('.remove-selection').length is 0
        @_removeSelectionButton = $('<a class="remove-selection"></a>')
          .attr('title', i18n.tips.removeSelection)
          .button(
            icons: 
              primary: 'remove-selection small'
            text: false
            disabled: true
          ).appendTo(bar).click @_onRemoveSelection
      bar

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new Map()

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      # data needed by the template
      title: _.sprintf i18n.titles.map, @model.id
      i18n: i18n

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    _specificRender: =>
      super()
      @_kindWidget = @$el.find('select.field').change =>
        kind = @_kindWidget.find('option:selected').val()
        if kind of Renderers and @_mapWidget?
          @_mapWidget.setOption 'renderer', new Renderers[kind]() 
        @_onChange()

      @_tileDimWidget = @$el.find('.tileDim.field').property(
        type: 'integer'
        allowNull: false
      ).on('change', @_refreshTileDim
      ).data 'property'

      # hide commands until map created
      if @_isNew
        @$el.find('.commands').hide()
        @$el.find('.not-saved').show()
      else
        @$el.find('.commands').show()
        @$el.find('.not-saved').hide()
        # no map until saved
        @_mapWidget = @$el.find('.map').authoringMap(
          lowerCoord: {x:0, y:0}
          displayGrid: true
          displayMarkers: true
          tileDim: @model.tileDim
          height: 601
          width: 901
          mapId: @model.id
          dndType: i18n.constants.fieldAffectation
        ).on('affect', @_onAffect
        ).on('coordChanged', =>
          # reloads map content
          return if @_isNew
          @model.consult @_mapWidget.options.lowerCoord, @_mapWidget.options.upperCoord
        ).on('selectionChanged', =>
          # update action bar button state
          @_removeSelectionButton.button 'option', 'disabled', @_mapWidget.options.selection.length is 0
        ).on('zoomChanged', =>
          @_inhibitZoom = true
          @$el.find('.zoom').val @_mapWidget.options.zoom
        ).data 'authoringMap'

        # update map commands
        @$el.find('.toggle-grid').removeAttr 'checked'
        @$el.find('.toggle-grid').attr 'checked', 'checked' if @_mapWidget.options.displayGrid
        @$el.find('.toggle-markers').removeAttr 'checked'
        @$el.find('.toggle-markers').attr 'checked', 'checked' if @_mapWidget.options.displayMarkers
        @$el.find('.zoom').val @_mapWidget.options.zoom

      # initiate renderer
      @_kindWidget.change()

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      # superclass handles description image
      super()
      # update map kind
      @model.kind = @_kindWidget.find('option:selected').val()
      @model.tileDim = @_tileDimWidget.options.value

    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      kind = @model.kind
      # update kind rendering (before calling super)
      @_kindWidget.find('option:selected').removeAttr 'selected'
      @_kindWidget.find("option[value='#{kind}']").attr 'selected', 'selected'

      # tile dimension
      @_tileDimWidget.setOption 'value', @model.tileDim or 100
      
      if kind of Renderers and @_mapWidget?
        @_mapWidget.setOption 'renderer', new Renderers[kind]() 

      # superclass handles description image and trigger _onChange
      super()

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      # superclass handles description image
      comparable = super()
      # adds images
      comparable.push
        name: 'kind'
        original: @model.kind
        current: @_kindWidget.find('option:selected').val()
      ,
        name: 'tileDim'
        original: @model.tileDim
        current: @_tileDimWidget.options.value 

      comparable

    # **private**
    # Debounce method that updates map widget when tile dimension changes
    _refreshTileDim: =>
      @_onChange()
      # refresh also map 
      @_mapWidget.setOption 'tileDim', @_tileDimWidget.options.value

    # **private**
    # Multiple field affectation in the current map selection
    # Creates field instance, using selected field num
    #
    # @param type [FieldType] the used field type
    # @param random [Boolean] true to randomly affect image num
    _multipleAffect: (type, random) =>
      console.log "affect #{@_selectedImages.length} image(s) inside current selection in #{if random then 'random' else 'regular'} mode"
      return unless @_selectedImages.length isnt 0
      # first, remove existing fields
      @_onRemoveSelection()
      created = []
      # then creates new fields
      for coord, i in @_mapWidget.options.selection
        # create image num in regular or random mode
        idx = if random then Math.floor(Math.random()*@_selectedImages.length) else i%@_selectedImages.length
        created.push new Field
          mapId: @model.id
          typeId: type.id
          num: @_selectedImages[idx]
          x: coord.x
          y: coord.y
        
      # and saves them
      Field.collection.save created

    # **private**
    # extends inherited method to create map widget when needed
    _onCreated: (created) =>
      return unless @_saveInProgress
      super created
      # refresh rendering
      @_specificRender()
      @_fillRendering()
      
    # **private**
    # Field affectation handler.
    # Removes existing fields, and then creates new field with relevant type and image instead.
    # If affectation occurs in a multiple selection, displays a dialog to choose which image to affect
    #
    # @param event [Event] the drop event on map widget
    # @param details [Object] drop details:
    # @option details typeId [String] dragged field's type id
    # @option details num [Number] image number of the dragged field
    # @option details coord [Object] x and y coordinates of the drop tile
    # @option details inSelection [Boolean] indicates wheter the drop tile is in a multiple selection
    _onAffect: (event, details) =>
      unless details.inSelection
        # removes current field if needed
        existing = @_mapWidget.getData details.coord
        new Field(existing).destroy() if existing?

        # and add new one instead
        new Field(
          mapId: @model.id
          typeId: details.typeId
          num: details.num
          x: details.coord.x
          y: details.coord.y
        ).save()
      else
        # retrieves the field type
        type = FieldType.collection.get details.typeId
        return unless type
        # displays the multiple affectation dialog
        dialog = $("<div class=\"affect-field\" title=\"#{i18n.titles.multipleAffectation}\">#{i18n.msgs.multipleAffectation}</div>").dialog(
          modal: true
          close: (event) ->
            # unbound click handler and remove dialog
            $(this).find('.images-container > *').unbind()
            $(this).remove()
          buttons: [
            text: i18n.buttons.ok,
            icons:
              primary: 'valid small'
            click: (event) =>
              # triggers affectation and close window
              @_multipleAffect type, $('.affect-field input:checked').length is 1
              $('.affect-field').dialog 'close'
          ]
        )
        # empties selected images
        @_selectedImages = []
        # adds all possible field type images to the dialog
        container = $('<div class="images-container"></div>').appendTo dialog
        for image, i in type.images
          $('<span></span>').loadableImage(
            source: image
          ).attr('tabindex', 0).data('num', i).on('click keyup', (event) =>
            # for keypress, just take in account spaces
            return if event.type is 'keyup' and event.which isnt 32
            img = $(event.target).closest '.loadable'
            num = img.data 'num'
            img.toggleClass 'selected'
            # store image number inside the selecte array
            if img.hasClass 'selected'
              @_selectedImages.push num
            else
              @_selectedImages.splice @_selectedImages.indexOf(num), 1
          ).appendTo container
        # adds a random affectation checkbox
        $("<label><input type=\"checkbox\"/>#{i18n.labels.randomAffect}</label>").appendTo dialog

    # **private**
    # Field destruction handler.
    # Removes existing fields inside the map selection
    #
    # @param event [Event] the drop event on map widget
    # @param details [Object] drop details:
    # @option details typeId [String] dragged field's type id
    # @option details num [Number] image number of the dragged field
    # @option details coord [Object] x and y coordinates of the drop tile
    # @option details inSelection [Boolean] indicates wheter the drop tile is in a multiple selection
    _onRemoveSelection: (event) =>
      # gets JSON fields from map Widget that are selected
      removed = []
      for selected in @_mapWidget.options.selection
        data = @_mapWidget.getData selected
        removed.push new Field data if data?
      
      # creates Backbone models, and remove them in block
      Field.collection.destroy removed
      
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