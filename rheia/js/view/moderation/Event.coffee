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
  'moment'
  'utils/utilities'
  'i18n!nls/common'
  'i18n!nls/moderation'
  'text!tpl/event.html'
  'view/moderation/BaseLinkedView'
  'model/Event'
], ($, moment, utils, i18n, i18nModeration, template, BaseLinkedView, Event) ->

  i18n = $.extend true, i18n, i18nModeration

  # Displays and edit an Event in moderation perspective
  class EventView extends BaseLinkedView

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: Event.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeEventConfirm

    # **private**
    # widget to manage from
    _fromWidget: null

    # The view constructor.
    #
    # @param id [String] the edited object's id, null for creation
    # @param @_created [Object] a freshly created model, null for existing model
    constructor: (id, @_created) ->
      # superclass constructor
      super id, 'event-type event', @_created
      console.log "creates event edition view for #{if id? then @model.id else 'a new object'}"

    # **protected**
    # This method is intended to by overloaded by subclass to provide template data for rendering
    #
    # @return an object used as template data (this by default)
    _getRenderData: -> i18n: i18n, title: _.sprintf i18n.titles.event, @model.type.id, @model.id or '~'

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    #
    # Adds image carousel, map controls, and properties rendering
    _specificRender: =>
      @_fromWidget = @$el.find('.from').property(
        type: 'object'
        allowNull: true
        isInstance: true
        accepted: ['Item']
        tooltipFct: utils.instanceTooltip
      ).on('change', @_onChange
      ).on('open', (event, instance) =>
        # opens players, items, events
        app.router.trigger 'open', instance._className, instance.id
      ).data 'property'

      super()

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      super()
      # set from item
      @model.from = @_fromWidget.options.value

    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      # from item
      @_fromWidget.setOption 'value', @model.from

      # display creation and update dates
      @$el.find('.creation-date').html moment(@model.created).format i18n.constants.dateTimeFormat
      @$el.find('.update-date').html moment(@model.updated).format i18n.constants.dateTimeFormat

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
      return comparable unless @_fromWidget?

      comparable.push
        name: 'from'
        original: @model.from or null
        current: @_fromWidget.options.value

      comparable