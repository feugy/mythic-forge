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
  'i18n!nls/edition'
  'text!tpl/EventType.html'
  'view/edition/BaseEditionView'
  'utils/validators'
  'model/EventType'
  'widget/property'
], ($, _, i18n, template, BaseEditionView, validators, EventType) ->

  i18n = $.extend(true, {}, i18n)

  addImageClass = 'add-image'

  # Displays and edit an EventType on edition perspective
  # Triggers the following events:
  # - change: when the model save and remove status changed
  class EventTypeView extends BaseEditionView

    # **private**
    # name of the model class
    _modelClassName: 'EventType'

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
    # close popup confirmation text, that can take the edited object's name in parameter
    _confirmCloseMessage: i18n.msgs.closeConfirm

    # **private**
    # array of edited properties values, to distinct edited values from model values
    _editedProperties: {}

    # **private**
    # avoid to trigger property change handler while rendering, because it empties `_editedProperties`
    _inhibitPropertyChange: false

    # The view constructor.
    #
    # @param id [String] the edited object's id, of null for a creation.
    # @param className [String] css class used for this view, by default 'event-type'. Use by subclasses to override
    constructor: (id, className = 'event-type') ->
      super(id, className)
      console.log("creates event type edition view for #{if id? then @model.id else 'a new object'}")

    # Returns the view's action bar, and creates it if needed.
    #
    # @return the action bar rendering.
    getActionBar: () =>
      bar = super()
      # adds specific buttons
      if bar.find('.add-property').length is 0
        $('<a class="add-property"></a>')
          .attr('title', i18n.tips.addProperty)
          .button(
            icons: 
              primary: 'add-property small'
            text: false
          ).appendTo(bar).click(@_onNewProperty) 
      return bar

    # **private**
    # Effectively creates a new model.
    _createNewModel: () =>
      @model = new EventType()
      @model.set('name', i18n.labels.newName)
      @model.set('descImage', null)

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: () =>
      # superclass handles description image, name and description
      super()

      # totally replace model's property with the view ones
      properties = {}
      $.extend(true, properties, @_editedProperties)
      @model.set('properties', properties)
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: () =>
      # superclass handles description image, name and description
      super()

      # keep a copy of edited properties in the view
      @_editedProperties = {}
      $.extend(true, @_editedProperties, @model.get('properties'))
      # will trigger _onChange
      @_updateProperties()

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: () =>
      # data needed by the template
      return {
        title: _.sprintf(i18n.titles.eventType, if @_tempId? then i18n.labels.newType else @model.id)
        i18n: i18n
      }

    # **private**
    # Removes existing properties widget, and creates new ones from _editedProperties
    _updateProperties: () =>
      # unbinds existing handlers
      @$el.find('.properties > tbody > tr > td > *').unbind()
      
      # remove existing lines
      @$el.find('.properties > tbody > tr').remove()

      # and recreates lines
      @_inhibitPropertyChange = true
      for uidName, prop of @_editedProperties
        # a line for each property
        line = $("""<tr class="property"></tr>""").appendTo(@$el.find('.properties > tbody'))

        # removal button
        remove = $('<a href="#"></a>').button(
          icons:
            primary: 'remove x-small'
        ).click(@._onRemoveProperty).wrap('<td></td>')
        line.append(remove.parent())

        # input for property's name
        name = $("""<input class="uidName" type="text" value="#{uidName}"/>""")
            .keyup(@_onPropertyChange).wrap('<td></td>')
        line.append(name.parent())

        # select for property's type
        markup = '';
        for name, value of i18n.labels.propertyTypes
          markup += """<option value="#{name}" #{if prop.type is name then 'selected="selected"'}>#{value}</option>"""
        markup += '</select>';
        select = $("""<select class="type">#{markup}</select>""").change(@_onPropertyChange).wrap('<td></td>')
        line.append(select.parent())

        # at last, property widget for default value
        defaultValue = $('<div class="defaultValue"></div>').property(
          type: prop.type, 
          value: prop.def,
          change:@_onPropertyChange
        ).wrap('<td></td>')

        line.append(defaultValue.parent())
      
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
    _getComparableFields: () =>
      # superclass handles description image, name and description 
      comparable = super()
      # adds properties
      comparable.push(
        name: 'properties'
        original: @model.get('properties')
        current: @_editedProperties)
      return comparable
    
    # **private**
    # Re-creates validators, when refreshing the properties.
    # Existing validators are trashed, and validators created for:
    # - name
    # - properties' uidName
    # - sprite names
    _createValidators: () =>
      # superclass disposes validators, and creates name validator
      super()
      # adds a validator per properties
      for uidName in @$el.find('.properties input.uidName')

        @_validators.push(new validators.Regexp({
          invalidError: i18n.msgs.invalidUidError
          regexp: /^[$_\u0041-\uff70].*$/i
          required: true
          spacesAllowed: false
        }, i18n.labels.propertyUidField, $(uidName), null))

    # **private**
    # Some properties changed, either its name, type or its default value.
    # Updates view's property values
    # 
    # @param event [Event] change event on the modified property
    _onPropertyChange: (event) =>
      return if @_inhibitPropertyChange
      # get the property index
      rows = $(event.target).closest('.properties').find('tbody > tr')
      newProperties = {}
      for row in rows
        row = $(row)
        uidName = row.find('.uidName').val()
        newType = row.find('.type').val()
        # updates default value if type changes
        if newType isnt @_editedProperties[uidName]?.type
          row.find('.defaultValue').property('option', 'type', newType)
        newProperties[uidName] = {
          type: newType
          def: row.find('.defaultValue').data('property').options.value
        }

      @_editedProperties = newProperties
      # triggers validation
      @_onChange()

    # **private**
    # Add a new property at table top
    # 
    # @param event [Event] click event on the add property button
    _onNewProperty: (event) =>
      @_editedProperties[i18n.labels.propertyDefaultName] = {
        type: 'string'
        def: ''
      }
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

  return EventTypeView