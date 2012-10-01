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
  'i18n!nls/common'
  'i18n!nls/moderation'
  'text!tpl/item.html'
  'view/BaseEditionView'
  'model/Item'
  'model/Map'
  'widget/carousel'
  'widget/property'
], ($, _, i18n, i18nModeration, template, BaseEditionView, Item, Map) ->

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
    _confirmRemoveMessage: 'TODO'

    # **private**
    # Item type of this item
    _type: null

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

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id) ->
      super id, 'item-type'

      @_type = @model.get 'type'

      @bindTo Map.collection, 'add', @_onMapListRetrieved
      # TODO closes view if model's map is removed
      @bindTo Map.collection, 'remove', @_onMapListRetrieved

      console.log "creates item edition view for #{if id? then @model.id else 'a new object'}"

    # Returns the view's title: instance `name` properties, or type's name
    #
    # @return the edited object name.
    getTitle: => 
      """#{_.truncate (@model.get('properties')?.name or @_type.get 'name'), 15}
      <div class='uid'>(#{@model.id})</div>"""

    # **protected**
    # This method is intended to by overloaded by subclass to provide template data for rendering
    #
    # @return an object used as template data (this by default)
    _getRenderData: -> i18n: i18n, title: _.sprintf i18n.titles.item, @_type.get('name'), @model.id

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      throw new Error "not implemented yet"

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    #
    # Adds image carousel, map controls, and properties rendering
    _specificRender: =>
      # creates image carousel and map rendering
      @_imageWidget = @$el.find('.left .image').carousel(
        images: _.pluck @_type.get('images'), 'file'
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
      @model.set 'y', @_xWidget.options.value
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      # image number
      @_imageWidget.setOption 'current', @model.get 'imageNum'

      # map ownership
      @_mapList.find("[value='#{@model.get('map')?.id}']").attr 'selected', 'selected'
      @_xWidget.setOption 'value', @model.get 'x'
      @_yWidget.setOption 'value', @model.get 'y'

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

      comparable.push
        # image number
        name: 'imageNum'
        original: @model.get 'imageNum'
        current: @_imageWidget.options.current
      ,
        # map ownership
        name: 'map'
        original: @model.get('map')?.id
        current: @_mapList.find('option').filter(':selected').val()
      ,
        name: 'x'
        original: @model.get 'x'
        current: @_xWidget.options.value
      ,
        name: 'y'
        original: @model.get 'y'
        current: @_yWidget.options.value

      comparable

    # **private**
    # Empties and fills the map list.
    _onMapListRetrieved: =>
      maps = "<option value='none'>#{i18n.labels.noMap}</option>"
      maps += "<option value='#{map.id}'>#{map.get 'name'}</option>" for map in Map.collection.models   
      @_mapList.empty().append maps      

      @_mapList.find("[value='#{@model.get('map')?.id}']").attr 'selected', 'selected' if @model?.get('map')?