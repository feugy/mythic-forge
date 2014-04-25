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
  'i18n!nls/edition'
  'text!tpl/eventType.html'
  'view/BaseEditionView'
  'utils/validators'
  'model/EventType'
  'widget/property'
], ($, _, utils, i18n, i18nEdition, template, BaseEditionView, validators, EventType) ->

  i18n = $.extend true, i18n, i18nEdition

  addImageClass = 'add-image'

  # Displays and edit an EventType on edition perspective
  # Triggers the following events:
  # - change: when the model save and remove status changed
  class EventTypeView extends BaseEditionView

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: EventType.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeEventTypeConfirm

    # **private**
    # array of edited properties values, to distinct edited values from model values
    _editedProperties: {}

    # **private**
    # avoid to trigger property change handler while rendering, because it empties `_editedProperties`
    _inhibitPropertyChange: false

    # **private**
    # widget to edit event type template
    _templateWidget: null

    # The view constructor.
    #
    # @param id [String] the edited object's id, of null for a creation.
    # @param className [String] css class used for this view, by default 'event-type'. Use by subclasses to override
    constructor: (id, className = 'event-type') ->
      super id, className
      console.log "creates event type edition view for #{if id? then @model.id else 'a new object'}"

    # Returns the view's action bar, and creates it if needed.
    #
    # @return the action bar rendering.
    getActionBar: =>
      bar = super()
      # adds specific buttons
      if bar.find('.add-property').length is 0
        $('<a class="add-property"></a>')
          .attr('title', i18n.tips.addProperty)
          .button(
            icons: 
              primary: 'add-property small'
            text: false
          ).appendTo(bar).click @_onNewProperty
      bar

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new EventType()
      @model.descImage = null

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    #
    # Creates validator and instanciate widgets
    _specificRender: =>
      # inherited behaviour
      super()

      # creates property template
      @_templateWidget = @$el.find(".template.field").property(
        type: 'text'
        allowNull: false
      ).on('change', @_onChange
      ).data 'property'

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      # superclass handles description image
      super()

      # update template
      @model.template = @_templateWidget.options.value if @_templateWidget?

      # totally replace model's property with the view ones
      properties = {}
      $.extend true, properties, @_editedProperties
      @model.properties = properties
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      # superclass handles description image
      super()

      # update template
      @_templateWidget.setOption 'value', @model.template if @_templateWidget?

      # keep a copy of edited properties in the view
      @_editedProperties = {}
      $.extend true, @_editedProperties, @model.properties
      @_editedProperties = utils.sortAttributes @_editedProperties
      # will trigger _onChange
      @_updateProperties()

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      # data needed by the template
      title: _.sprintf i18n.titles.eventType, @model.id
      i18n: i18n

    # **private**
    # Removes existing properties widget, and creates new ones from _editedProperties
    _updateProperties: () =>
      # unbinds existing handlers
      @$el.find('.properties > tbody > tr > td > *').off()
      
      # remove existing lines
      @$el.find('.properties > tbody > tr').remove()

      # and recreates lines
      @_inhibitPropertyChange = true
      for uidName, prop of @_editedProperties
        # a line for each property
        line = $("""<tr class="property"></tr>""").appendTo @$el.find '.properties > tbody'

        # removal button
        remove = $('<a href="#"></a>').button(
          icons:
            primary: 'remove x-small'
        ).click(@._onRemoveProperty).wrap '<td></td>'
        line.append remove.parent()

        # input for property's name
        name = $("""<input class="uidName" type="text" value="#{uidName}"/>""")
            .on('keyup', @_onPropertyChange).wrap '<td></td>'
        line.append name.parent()

        # select for property's type
        markup = '';
        for name, value of i18n.labels.propertyTypes
          markup += """<option value="#{name}" #{if prop.type is name then 'selected="selected"'}>#{value}</option>"""
        markup += '</select>';
        select = $("""<select class="type">#{markup}</select>""").on('change', @_onPropertyChange).wrap '<td></td>'
        line.append select.parent()

        # at last, property widget for default value
        defaultValue = $('<div class="defaultValue"></div>').property(
          type: prop.type, 
          value: prop.def,
        ).on('change', @_onPropertyChange
        ).wrap '<td></td>'

        line.append defaultValue.parent()
      
      # re-creates all validators.
      @_createValidators()

      # trigger comparison
      @_inhibitPropertyChange = false
      @_onChange()
    
    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      # superclass handles description image, name and description 
      comparable = super()
      # adds properties
      comparable.push
        name: 'properties'
        original: @model.properties
        current: @_editedProperties
      
      if @_templateWidget?
        comparable.push
          name: 'template'
          original: @model.template
          current: @_templateWidget.options.value

      comparable
    
    # **private**
    # Re-creates validators, when refreshing the properties.
    # Existing validators are trashed, and validators created for:
    # - name
    # - properties' uidName
    # - sprite names
    _createValidators: =>
      # superclass disposes validators, and creates name validator
      super()
      # adds a validator per properties
      for uidName in @$el.find '.properties input.uidName'

        @_validators.push new validators.Regexp {
          invalidError: i18n.msgs.invalidUidError
          regexp: i18n.constants.uidRegex
          required: true
          spacesAllowed: false
        }, i18n.labels.propertyUidField, $(uidName), null

    # **private**
    # Allows subclass to add specific errors to be displayed when validating.
    # Check that Json fields are valid 
    #
    # @return an empty array of errors by default.
    _specificValidate: =>
      errors = []
      for uidName, prop of @_editedProperties when prop.type is 'json'
        editor = @$el.find(".properties .uidName[value='#{uidName}']").parents('tr').find('.defaultValue').data 'property'
        if editor?.options?.errors
          for err in editor.options.errors
            errors.push msg: "#{uidName} : #{err?.msg}" 
      errors

    # **private**
    # Some properties changed, either its name, type or its default value.
    # Updates view's property values
    # 
    # @param event [Event] change event on the modified property
    _onPropertyChange: (event) =>
      return if @_inhibitPropertyChange
      # get the property index
      rows = $(event.target).closest('.properties').find 'tbody > tr'
      newProperties = {}
      for row in rows
        row = $(row)
        uidName = row.find('.uidName').val()
        newType = row.find('.type').val()
        # updates default value if type changes
        if newType isnt @_editedProperties[uidName]?.type
          row.find('.defaultValue').property 'setOption', 'type', newType
        newProperties[uidName] =
          type: newType
          def: row.find('.defaultValue').data('property').options.value

      @_editedProperties = utils.sortAttributes newProperties
      # triggers validation
      @_onChange()

    # **private**
    # Add a new property at table top
    # 
    # @param event [Event] click event on the add property button
    _onNewProperty: (event) =>
      @_editedProperties[i18n.labels.propertyDefaultName] =
        type: 'string'
        def: ''
      # and re-creates property rendering
      @_updateProperties()
      event?.preventDefault()
  
    # **private**
    # Removes a given property from the rendering.
    #
    # @param event [Event] click event on a remove button
    _onRemoveProperty: (event) =>
      name = $(event.target).parents('tr.property').find('.uidName').val()
      delete @_editedProperties[name]
      # and re-creates property rendering
      @_updateProperties()
      event?.preventDefault()