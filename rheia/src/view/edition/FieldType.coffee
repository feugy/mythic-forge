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
  'i18n!nls/common'
  'i18n!nls/edition'
  'text!tpl/fieldType.html'
  'view/BaseEditionView'
  'model/FieldType'
  'widget/loadableImage'
], ($, _, i18n, i18nEdition, template, BaseEditionView, FieldType) ->

  i18n = $.extend true, i18n, i18nEdition

  addImageClass = 'add-image'

  # Displays and edit an FieldType on edition perspective
  # Triggers the following events:
  # - change: when the model save and remove status changed
  class FieldTypeView extends BaseEditionView

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: FieldType.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeFieldTypeConfirm

    # **private**
    # instance images widget
    _imageWidgets: []

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id) ->
      super id, 'field-type'
      console.log "creates field type edition view for #{if id? then @model.id else 'a new object'}"

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new FieldType()
      @model.descImage = null

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      # superclass handles description image
      super()

      # update images specifications. File upload will be handled separately
      newImages = @_computeImageSpecs()
      newImages[i] = '' for image, i in newImages when image isnt null and typeof image isnt 'string'
      @model.images = newImages
      
    # **private**
    # Performs view specific save operations, right before saving the model.
    # Adds instance images to pending uploads. 
    #
    # @return optionnal arguments for the `save` Backbone method.
    _specificSave: () =>
      super()
      # keeps instance images uploads       
      currents = @_computeImageSpecs()
      originals = @model.images
      for current, i in currents
        # something changed !
        if !originals or originals[i] isnt current
          spec = file: current, idx: i
          if current is null
            spec.oldFile = originals[i]
          @_pendingUploads.push spec
      null

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      # data needed by the template
      title: _.sprintf i18n.titles.fieldType, @model.id
      i18n: i18n

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      # superclass handles description image
      comparable = super()
      # adds images

      comparable.push
        name: 'images'
        original: @model.images
        current: @_computeImageSpecs()
      comparable
    
    # **private**
    # Extract image specifications from the widgets
    # @return an array containing image specifications
    _computeImageSpecs: =>
      images = []
      length = @model.images?.length
      # do not save an empty spec that is beyond existing length
      images.push widget.options.source for widget,i in @_imageWidgets when i < length or widget.options.source?
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
          @_imageWidgets.push $('<div></div>').loadableImage(
            source: original
          ).on('change', @_onImageChange
          ).appendTo(container).data 'loadableImage'
      # a special image to add new images  
      @_addNewImage() 

    # **private**
    # Adds a special spriteImage widget to upload a new image
    _addNewImage: =>
      addImage = $('<div class="add-image"></div>').loadableImage(
      ).on('change', =>
          # is it an upload ?
          if addImage.options.source?
            # transforms it into a regular image widget
            addImage.$el.removeClass('add-image').
              off('change').
              on 'change', @_onImageChange
            @_imageWidgets.push addImage
            @_addNewImage()
          @_onChange()
      ).appendTo(@$el.find('.images-container')).data 'loadableImage'

    # **private**
    # Instance image change handler. Trigger the general _onChange handler after an optionnal widget removal.
    #
    # @param event [Event] image change event.
    _onImageChange: (event) =>
      # search for empty images widget from the last one
      removed = []
      for widget, i in @_imageWidgets
        if widget.options.source is null
          removed.push i
        else 
          removed = []
      # Destroy the found widgets
      @_imageWidgets.splice(i, 1)[0].$el.remove() for i in removed.reverse()
      @_onChange event