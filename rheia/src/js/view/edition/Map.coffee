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
  'underscore'
  'i18n!nls/edition'
  'text!view/edition/template/Map.html'
  'view/edition/BaseEditionView'
  'model/Map'
], ($, _, i18n, template, BaseEditionView, Map) ->

  i18n = $.extend(true, {}, i18n)

  # Displays and edit a map on edition perspective
  class MapView extends BaseEditionView

    # **private**
    # name of the model class
    _modelClassName: 'Map'

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
    # close popup confirmation text, that can take the edited object's name in parameter
    _confirmCloseMessage: i18n.msgs.closeConfirm

    # **private**
    # map kind rendering
    _kindWidget: null

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id) ->
      super(id, 'map')
      console.log("creates map edition view for #{if id? then @model.id else 'a new object'}")

    # **private**
    # Effectively creates a new model.
    _createNewModel: () =>
        @model = new Map()
        @model.set('name', i18n.labels.newName)

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: () =>
      # data needed by the template
      return {
        title: _.sprintf(i18n.titles.map, if @_tempId? then i18n.labels.newType else @model.id)
        i18n: i18n
      }

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    _specificRender: () =>
      @_kindWidget = @$el.find('select.field').change(@_onChange)

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: () =>
      # superclass handles description image, name and description
      super()

      # update map kind
      @model.set('kind', @_kindWidget.find('option:selected').val())

    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: () =>
      # update kind rendering (before calling super)
      @_kindWidget.find('option:selected').removeAttr('selected')
      @_kindWidget.find("option[value='#{@model.get('kind')}']").attr('selected', 'selected')

      # superclass handles description image, name and description, and trigger _onChange
      super()

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: () =>
      # superclass handles description image, name and description 
      comparable = super()
      # adds images
      comparable.push(
        name: 'kind'
        original: @model.get('kind')
        current: @_kindWidget.find('option:selected').val()
      )
      console.dir comparable
      return comparable

  return MapView