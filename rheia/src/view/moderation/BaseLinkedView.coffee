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
  'utils/utilities'
  'i18n!nls/common'
  'view/BaseExecutableView'
  'widget/property'
], ($, _, utils, i18n, BaseExecutableView) ->

  # A base view that brings properties functionnalities, with linked resolution and wutomatic property widget creation.
  # It assume that edited model is an instance that has a type.
  class BaseLinkedView extends BaseExecutableView

    # **private**
    # Temporary created model
    _created: null

    # **private**
    # array of property widgets
    _propWidgets: {}

    # The view constructor.
    #
    # @param id [String] the edited object's id, null for creation
    # @param className [String] rendering root node Css class.
    # @param @_created [Object] a freshly created model, null for existing model
    constructor: (id, className, @_created) ->
      # superclass constructor
      super id, className

      @_propWidgets = {}
      # Closes external changes warning after 5 seconds
      @_autoHideExternal = true

    # **private**
    # Effectively creates a new model.
    _createNewModel: => 
      @model = @_created
      @_created = null

    # Returns the view's title: instance `name` properties, or type's name
    #
    # @param confirm [Boolean] true to get the version of the title for confirm popups. Default to false.
    # @return the edited object name.
    getTitle: (confirm = false) => 
      return utils.instanceName @model if confirm
      "#{_.truncate utils.instanceName(@model), 15}<div class='uid'>(#{@model.id or '~'})</div>"

    # Returns the view's action bar, and creates it if needed.
    #
    # @return the action bar rendering.
    getActionBar: =>
      bar = super()
      # adds specific buttons
      if bar.find('.copy').length is 0
        $('<a href="#" class="copy"></a>')
          .attr('title', i18n.tips.copy)
          .button(
            icons: 
              primary: 'copy small'
            text: false
          ).appendTo(bar).click (event) =>
            event?.preventDefault()
            app.router.trigger 'copy', @model
      bar

    # **private**
    # Allows subclass to add specific errors to be displayed when validating.
    # Check that Json fields are valid 
    #
    # @return an empty array of errors by default.
    _specificValidate: =>
      errors = []
      for name, prop of @model?.type?.properties when prop.type is 'json' and @_propWidgets[name]?
        for err in @_propWidgets[name].options.errors
          errors.push msg: "#{name} : #{err?.msg}" 
      errors

    # **private**
    # Gets values from rendering and saved them into the edited object.
    # Fills properties from properties widgets
    _fillModel: =>
      super()
      # item properties
      for name, widget of @_propWidgets
        value = widget.options.value
        # stores only linked ids
        if widget.options.type is 'object'
          value = if value? then value.id else null
        else if widget.options.type is 'array'
          value = ((if obj? then obj.id else null) for obj in value)

        @model[name] = value
      
    # **private**
    # Updates rendering with values from the edited object.
    # Triggers the linked objects resolution
    _fillRendering: =>
      # resolve linked and draw properties
      @model.fetch @_onLinkedResolved
      super()

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    # Adds comparison for properties widgets
    #
    # @return the comparable fields array
    _getComparableFields: =>
      comparable = super()
      
      # linked properties
      for name, widget of @_propWidgets
        value = widget.options.value
        original = @model[name]


        # compare only linked ids
        if widget.options.type is 'object'
          value = if value? then value.id else null
          original = if original? then original.id else null
        else if widget.options.type is 'array'
          value = (obj?.id for obj in value)
          if Array.isArray original
            original = ((if obj? then obj.id else null) for obj in original)
          else 
            original = []

        comparable.push 
          name: name
          original: original
          current: value

      comparable

    # **private**
    # Avoid warning popup when edited object have been modified removed.
    _notifyExternalRemove: =>

    # **private**
    # Invoked when a model is created on the server.
    #
    # @param created [Object] the created model
    _onCreated: (created) =>
      # inherited class behaviour
      super created
      # update view title
      @$el.find('> h1').html @_getRenderData().title

    # **private**
    # Handler invoked when items and events linked to this instance where resolved
    # (Re)Creates the rendering
    _onLinkedResolved: =>
      container = @$el.find '> table'

      # unbinds existing handlers and removes lines
      widget.$el.remove() for name, widget of @_propWidgets
      @_propWidgets = {}
      container.find('tr.prop').remove()

      # creates a property widget for each type's properties
      properties = utils.sortAttributes @model.type.properties
      for name, prop of properties
        value = @model[name]
        if value is undefined
          if prop.type is 'object'
            value = null
          else if prop.type is 'array'
            value = []
          else
            value = prop.def

        accepted = []
        if (prop.type is 'object' or prop.type is 'array') and prop.def isnt 'Any'
          accepted = [prop.def]
        row = $("<tr class='prop'><td class='left'>#{name}#{i18n.labels.fieldSeparator}</td></tr>").appendTo container
        @_propWidgets[name] = $('<td class="right"></td>').property(
          type: prop.type
          value: value
          isInstance: true
          accepted: accepted
          tooltipFct: utils.instanceTooltip
        ).on('change', @_onChange
        ).on('open', (event, instance) =>
          # opens players, items, events
          app.router.trigger 'open', instance._className, instance.id
        ).appendTo(row).data 'property'

      @_onChange()