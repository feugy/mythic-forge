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
  'i18n!nls/edition'
  'text!tpl/itemType.html'
  'view/edition/EventType'
  'model/ItemType'
  'widget/spriteImage'
], ($, _, i18n, i18nEdition, template, EventTypeView, ItemType) ->

  i18n = $.extend true, i18n, i18nEdition

  # Displays and edit an ItemType on edition perspective
  # Triggers the following events:
  # - change: when the model save and remove status changed
  class ItemTypeView extends EventTypeView

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
      super id, 'item-type'
      console.log "creates item type edition view for #{if id? then @model.id else 'a new object'}"

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new ItemType()
      @model.name = i18n.labels.newName
      @model.descImage = null

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      # superclass handles description image, name, description and properties
      super()

      @model.quantifiable = @_quantifiable.attr('checked') isnt undefined

      # update images specifications. File upload will be handled separately
      newImages = @_computeImageSpecs()
      image.file = '' for image in newImages when image.file isnt null and typeof image.file isnt 'string'
      @model.images = newImages
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      if @model.quantifiable
        @_quantifiable.attr 'checked', 'checked'
      else 
        @_quantifiable.removeAttr 'checked'

      # superclass handles description image, name, description and properties
      super()

    # **private**
    # Performs view specific save operations, right before saving the model.
    # Adds instance images to pending uploads. 
    #
    # @return optionnal arguments for the `save` Backbone method.
    _specificSave: =>
      super()
      # keeps instance images uploads       
      currents = @_computeImageSpecs()
      originals = @model.images
      for current, i in currents
        # something changed !
        if !originals or originals[i]?.file isnt current.file
          current.idx = i
          @_pendingUploads.push current

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      # data needed by the template
      {
        title: _.sprintf i18n.titles.itemType, if @_tempId? then i18n.labels.newType else @model.id
        i18n: i18n
      }

    # **private**
    # Performs view specific rendering operations.
    # Bind quantifiable rendering to change event.
    _specificRender: =>
      super()
      @_quantifiable = @$el.find('.quantifiable.field').on 'change', @_onChange
    
    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      # superclass handles description image, name, description and properties
      comparable = super()
      # adds name and description
      comparable.push
        name: 'quantifiable'
        original: @model.quantifiable
        current: @_quantifiable.attr('checked') isnt undefined
      # adds images
      comparable.push
        name: 'images'
        original: @model.images
        current: @_computeImageSpecs()
      comparable

    # **private**
    # Allows subclass to add specific errors to be displayed when validating.
    # Validates sprite definitions.
    #
    # @return errors of sprite widgets
    _specificValidate: =>
      errors = []
      # we need to performs spriteImage widget validation
      for sprite in @_imageWidgets
        errors = errors.concat sprite.options.errors
      errors = errors.concat @$el.find('.add-image.sprite').data('spriteImage').options.errors
      errors

    # **private**
    # Extract image specifications from the widgets
    # @return an array containing image specifications
    _computeImageSpecs: =>
      images = []
      length = @model.images?.length
      for widget,i in @_imageWidgets 
        spec = 
          file: widget.options.source
          width: widget.options.spriteW
          height: widget.options.spriteH
        unless _.isEmpty widget.options.sprites
          spec.sprites = widget.options.sprites
        if widget.options.source is null
          if i < length
            spec.oldName = @model.images[i].file
          else 
            # do not save an empty spec that is beyond existing length
            continue
        images.push spec
      images

    # **private**
    # Creates LoadableImage for each images of the edited object
    _createImages: =>
      # superclass handles the description image
      super()
      # instances images: use sprite widget instead of loadable images
      @_imageWidgets = []
      originals = @model.images
      container = @$el.find('.images-container').empty()
      if originals?
        # creates images widgets
        for original in originals
          @_imageWidgets.push $('<div></div>').spriteImage(
            source: original.file
            spriteW: original.width
            spriteH: original.height
            sprites: original.sprites
          ).on('change', @_onImageChange
          ).appendTo(container).data 'spriteImage'
      # a special image to add new images  
      @_addNewImage() 

    # **private**
    # Adds a special spriteImage widget to upload a new image
    _addNewImage: =>
      addImage = $('<div class="add-image"></div>').spriteImage(
      ).on('change', (event, arg) =>
          # is it an upload ?
          if (!arg or !arg.isSprite) and addImage.options.source?
            # transforms it into a regular image widget
            addImage.$el.removeClass('add-image').
              off('change').
              on 'change', @_onImageChange
            @_imageWidgets.push addImage
            @_addNewImage()
          @_onChange()
      ).appendTo(@$el.find('.images-container')).data 'spriteImage'

    # **private**
    # Instance image change handler. Trigger the general _onChange handler after an optionnal widget removal.
    #
    # @param event [Event] image change event.
    _onImageChange: (event) =>
      # remove from images widget if it's the last widget
      widget = $(event.target).closest('.loadable').data 'spriteImage'
      if widget.options.source is null and @_imageWidgets.indexOf(widget) is @_imageWidgets.length-1
        @_imageWidgets.splice @_imageWidgets.length-1, 1
        widget.$el.remove()
      @_onChange event