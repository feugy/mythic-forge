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

  return MapView