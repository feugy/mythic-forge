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
  'text!view/edition/template/ItemType.html'
  'view/edition/BaseEditionView'
  'utils/validators'
  'model/ItemType'
  'widget/spriteImage'
  'widget/property'
], ($, _, i18n, template, BaseEditionView, validators, ItemType) ->

  i18n = $.extend(true, {}, i18n)

  addImageClass = 'add-image'

  # Displays and edit an ItemType on edition perspective
  # Triggers the following events:
  # - change: when the model save and remove status changed
  class ItemTypeView extends BaseEditionView

    # **private**
    # name of the model class
    _modelClassName: 'ItemType'

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: ItemType.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeItemTypeConfirm
    
    # **private**
    # close popup confirmation text, that can take the edited object's name in parameter
    _confirmCloseMessage: i18n.msgs.closeConfirm

    # **private**
    # array of edited properties values, to distinct edited values from model values
    _editedProperties: {}

    # **private**
    # avoid to trigger property change handler while rendering, because it empties `_editedProperties`
    _inhibitPropertyChange: false

    # **private**
    # checkbox that displays the model's quantifiable property
    _quantifiable: null

    # **private**
    # instance images widget
    _imageWidgets: []

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id) ->
      super(id, 'item-type')
      console.log("creates item type edition view for #{if id? then @model.id else 'a new object'}")

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
        @model = new ItemType()
        @model.set('name', i18n.labels.newName)
        @model.set('descImage', null)

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: () =>
      # superclass handles description image, name and description
      super()

      @model.set('quantifiable', @_quantifiable.attr('checked') isnt undefined)

      # update images specifications. File upload will be handled separately
      newImages = @_computeImageSpecs()
      image.file = '' for image in newImages when image.file isnt null and typeof image.file isnt 'string'
      @model.set('images', newImages)

      # totally replace model's property with the view ones
      properties = {}
      $.extend(true, properties, @_editedProperties)
      @model.set('properties', properties)
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: () =>
      # superclass handles description image, name and description
      super()

      if @model.get('quantifiable')
        @_quantifiable.attr('checked', 'checked') 
      else 
        @_quantifiable.removeAttr('checked')
      # keep a copy of edited properties in the view
      @_editedProperties = {}
      $.extend(true, @_editedProperties, @model.get('properties'))
      # will trigger _onChange
      @_updateProperties()

    # **private**
    # Performs view specific save operations, right before saving the model.
    # Adds instance images to pending uploads. 
    #
    # @return optionnal arguments for the `save` Backbone method.
    _specificSave: () =>
      # keeps instance images uploads       
      currents = @_computeImageSpecs()
      originals = @model.get('images')
      for current, i in currents
        # something changed !
        if !originals or originals[i]?.file isnt current.file
          current.idx = i
          @_pendingUploads.push(current)

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: () =>
      # data needed by the template
      return {
        title: _.sprintf(i18n.titles.itemType, if @_tempId? then i18n.labels.newType else @model.id)
        i18n: i18n
      }

    # **private**
    # Performs view specific rendering operations.
    # Bind quantifiable rendering to change event.
    _specificRender: () =>
      @_quantifiable = @$el.find('.quantifiable.field').change(@_onChange)

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
      # adds name and description
      comparable.push(
        name: 'quantifiable'
        original: @model.get('quantifiable')
        current: @_quantifiable.attr('checked') isnt undefined)
      # adds images
      comparable.push(
        name: 'images'
        original: @model.get('images')
        current: @_computeImageSpecs())
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
    # Allows subclass to add specific errors to be displayed when validating.
    # Validates sprite definitions.
    #
    # @return errors of sprite widgets
    _specificValidate: () =>
      errors = []
      # we need to performs spriteImage widget validation
      for sprite in @_imageWidgets
        errors = errors.concat(sprite.options.errors)
      errors = errors.concat(@$el.find('.add-image.sprite').data('spriteImage').options.errors)
      return errors

    # **private**
    # Extract image specifications from the widgets
    # @return an array containing image specifications
    _computeImageSpecs: () =>
      images = []
      length = @model.get('images')?.length
      for widget,i in @_imageWidgets 
        spec = 
          file: widget.options.source
          width: widget.options.spriteW
          height: widget.options.spriteH
          sprites: widget.options.sprites
        if widget.options.source is null
          if i < length
            spec.oldName = @model.get('images')[i].file
          else 
            # do not save an empty spec that is beyond existing length
            continue
        images.push(spec)
      return images

    # **private**
    # Creates LoadableImage for each images of the edited object
    _createImages: () =>
      # superclass handles the description image
      super()
      # instances images: use sprite widget instead of loadable images
      @_imageWidgets = []
      originals = @model.get('images')
      container = @$el.find('.images-container').empty()
      if originals?
        # creates images widgets
        for original in originals
          @_imageWidgets.push($('<div></div>').spriteImage(
            source: original.file
            spriteW: original.width
            spriteH: original.height
            sprites: original.sprites
            change: @_onImageChange
          ).appendTo(container).data('spriteImage'))
      # a special image to add new images  
      @_addNewImage() 

    # **private**
    # Adds a special spriteImage widget to upload a new image
    _addNewImage: () =>
      addImage = $('<div class="add-image"></div>').spriteImage(
        change: (event, arg) =>
          # is it an upload ?
          if arg? and !arg.isSprite and addImage.options.source isnt null
            # transforms it into a regular image widget
            addImage.element.removeClass('add-image')
            addImage.change = @_onImageChange
            @_imageWidgets.push(addImage)
            @_addNewImage()
          @_onChange()
      ).appendTo(@$el.find('.images-container')).data('spriteImage')

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

    # **private**
    # Instance image change handler. Trigger the general _onChange handler after an optionnal widget removal.
    #
    # @param event [Event] image change event.
    _onImageChange: (event) =>
      # remove from images widget if it's the last widget
      widget = $(event.target).closest('.loadable').data('spriteImage')
      if widget.options.source is null and @_imageWidgets.indexOf(widget) is @_imageWidgets.length-1
        @_imageWidgets.splice(@_imageWidgets.length-1, 1)
        widget.element.remove()
      @_onChange(event)

  return ItemTypeView