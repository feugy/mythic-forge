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
  'underscore'
  'utils/utilities'
  'i18n!nls/common'
  'i18n!nls/moderation'
  'text!tpl/item.html'
  'view/BaseEditionView'
  'model/Item'
  'model/Map'
  'widget/carousel'
  'widget/property'
], ($, _, utils, i18n, i18nModeration, template, BaseEditionView, Item, Map) ->

  i18n = $.extend true, i18n, i18nModeration

  # Displays and edit an Item in moderation perspective
  class ItemView extends BaseEditionView

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: Item.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeItemConfirm

    # **private**
    # Temporary created model
    _created: null

    # **private**
    # indicates wether or not this item has quantity
    _hasQuantity: false

    # **private**
    # select to display current map
    _mapList: null

    # **private**
    # field to input abscissa
    _xWidget: null

    # **private**
    # field to input ordinate
    _yWidget: null

    # **private**
    # image carousel widget
    _imageWidget: null

    # **private**
    # widget to manage quantity
    _quantityWidget: null

    # **private**
    # array of property widgets
    _propWidgets: {}

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param idOrModel [String] the edited object's id, null for creation
    # @param @_created [Object] a freshly created model
    constructor: (id, @_created) ->
      # superclass constructor
      super id, 'item-type'

      # bind to map collection events: update map list.
      @bindTo Map.collection, 'add', @_onMapListRetrieved
      @bindTo Map.collection, 'remove', (map) => 
        if @model.get('map')?.equals map 
          # the item's map is removed: closes view
          @_removeInProgress = true
          @_onRemoved @model
        else 
          @_onMapListRetrieved()

      @_propWidgets = {}

      # Closes external changes warning after 5 seconds
      @_emptyExternalChange = _.debounce (=> @$el.find('.external-change *').hide 200, -> $(@).remove()), 5000

      console.log "creates item edition view for #{if id? then @model.id else 'a new object'}"

    # **private**
    # Effectively creates a new model.
    _createNewModel: => 
      @model = @_created
      @_created = null

    # Returns the view's title: instance `name` properties, or type's name
    #
    # @return the edited object name.
    getTitle: => 
      "#{_.truncate utils.instanceName(@model), 15}<div class='uid'>(#{@model.id})</div>"

    # **protected**
    # This method is intended to by overloaded by subclass to provide template data for rendering
    #
    # @return an object used as template data (this by default)
    _getRenderData: -> i18n: i18n, title: _.sprintf i18n.titles.item, @model.get('type').get('name'), @model.id

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    #
    # Adds image carousel, map controls, and properties rendering
    _specificRender: =>
      # creates image carousel and map rendering
      @_imageWidget = @$el.find('.left .image').carousel(
        images: _.pluck @model.get('type').get('images'), 'file'
        change: @_onChange
      ).data 'carousel'

      @_mapList = @$el.find '.map.field'
      @_mapList.on 'change', =>
        # enable/disable coordinates
        mapId = @_mapList.find('option').filter(':selected').val()
        if mapId is 'none'
          @_xWidget?.setOption 'value', null
          @_yWidget?.setOption 'value', null
        else
          @_xWidget?.setOption 'value', @model.get('x') or 0
          @_yWidget?.setOption 'value', @model.get('y') or 0
        @_onChange()

      @_onMapListRetrieved()

      @_xWidget = @$el.find('.x.field').property(
        type: 'integer'
        allowNull: true
        change: @_onChange
      ).data 'property'

      @_yWidget = @$el.find('.y.field').property(
        type: 'integer'
        allowNull: true
        change: @_onChange
      ).data 'property' 

      @_quantityWidget = @$el.find('.quantity.field').property(
        type: 'float'
        allowNull: false
        change: @_onChange
      ).data 'property'

      super()

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      super()

      # image number
      @model.set 'imageNum', @_imageWidget.options.current

      # map ownership
      @model.set 'map', Map.collection.get @_mapList.find('option').filter(':selected').val()
      @model.set 'x', @_xWidget.options.value
      @model.set 'y', @_yWidget.options.value
      @model.set 'quantity', @_quantityWidget.options.value if @_hasQuantity

      # item properties
      for name, widget of @_propWidgets
        value = widget.options.value
        # stores only linked ids
        if widget.options.type is 'object'
          value = value?.id
        else if widget.options.type is 'array'
          value = (obj?.id for obj in value)

        @model.set name, value
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      @_hasQuantity = @model.get('type')?.get 'quantifiable'
      @$el.find('.quantity').toggle @_hasQuantity
      
      # image number
      @_imageWidget.setOption 'current', @model.get 'imageNum'

      # map ownership
      @_mapList.find("[value='#{@model.get('map')?.id}']").attr 'selected', 'selected'
      @_xWidget.setOption 'value', @model.get 'x'
      @_yWidget.setOption 'value', @model.get 'y'
      @_quantityWidget.setOption 'value', @model.get 'quantity' if @_hasQuantity

      # resolve linked and draw properties
      @model.resolve @_onItemResolved
      super()

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      comparable = super()
      return comparable unless @_yWidget?

      mapValue =  @_mapList.find('option').filter(':selected').val()
      mapValue = undefined if mapValue is 'none'
      comparable.push
        # image number
        name: 'imageNum'
        original: @model.get 'imageNum'
        current: @_imageWidget.options.current
      ,
        # map ownership
        name: 'map'
        original: @model.get('map')?.id
        current: mapValue
      ,
        name: 'x'
        original: @model.get 'x'
        current: @_xWidget.options.value
      ,
        name: 'y'
        original: @model.get 'y'
        current: @_yWidget.options.value

      if @_hasQuantity
        comparable.push 
          name: 'quantity'
          original: @model.get 'quantity'
          current: @_quantityWidget.options.value 

      # item properties
      for name, widget of @_propWidgets
        value = widget.options.value
        original = @model.get name

        # compare only linked ids
        if widget.options.type is 'object'
          value = value?.id
          original = original?.id
        else if widget.options.type is 'array'
          value = (obj?.id for obj in value)
          original = (obj?.id for obj in original)

        comparable.push 
          name: name
          original: original
          current: value

      comparable

    # **private**
    # Avoid warning popup when edited object have been modified externally, and temorary displays a warning inside tab.
    _notifyExternalChange: =>
      @_emptyExternalChange()
      if @$el.find('.external-change *').length is 0
        @$el.find('.external-change').append "<p>#{i18n.msgs.itemExternalChange}</p>"

    # **private**
    # Empties and fills the map list.
    _onMapListRetrieved: =>
      maps = "<option value='none'>#{i18n.labels.noMap}</option>"
      maps += "<option value='#{map.id}'>#{map.get 'name'}</option>" for map in Map.collection.models   
      @_mapList.empty().append maps      

      @_mapList.find("[value='#{@model.get('map')?.id}']").attr 'selected', 'selected' if @model?.get('map')?

    # **private**
    # Handler invoked when items and events linked to this item where resolved
    # (Re)Creates the rendering
    _onItemResolved: =>
      container = @$el.find '> table'

      # unbinds existing handlers and removes lines
      widget.destroy() for name, widget of @_propWidgets
      @_propWidgets = {}
      container.find('tr.prop').remove()

      # creates a property widget for each type's properties
      properties = utils.sortAttributes @model.get('type').get 'properties'
      for name, prop of properties
        value = @model.get name
        value = prop.def if value is undefined
        accepted = []
        if (prop.type is 'object' or prop.type is 'array') and prop.def isnt 'Any'
          accepted = [prop.def]
        row = $("<tr class='prop'><td class='left'>#{name}#{i18n.labels.fieldSeparator}</td></tr>").appendTo container
        widget = $('<td class="right"></td>').property(
          type: prop.type
          value: value
          isInstance: true
          accepted: accepted
          tooltipFct: utils.instanceTooltip
          open: (event, instance) =>
            # opens players, items, events
            rheia.router.trigger 'open', instance.constructor.name, instance.id
        ).appendTo(row).data 'property'
        @_propWidgets[name] = widget
        widget.setOption 'change', @_onChange