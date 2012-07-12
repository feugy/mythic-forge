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
  'i18n!nls/edition'
  'utils/utilities'
  'utils/Milk'
  'utils/validators'
], (i18n, utilities, Milk, validators) ->

  i18n = $.extend(true, {}, i18n)

  # Base class for edition views
  class BaseEditionView extends Backbone.View

    # the edited object
    model: null    

    # **private**
    # mustache template rendered
    # **Must be defined by subclasses**
    _template: null

    # **private**
    # models collection on which the view is bound
    # **Must be defined by subclasses**
    _collection: null

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    # **Must be defined by subclasses**
    _confirmRemoveMessage: null
    
    # **private**
    # close popup confirmation text, that can take the edited object's name in parameter
    # **Must be defined by subclasses**
    _confirmCloseMessage: null

    # **private**
    # flag that indicates the savable state of the model
    _canSave: false

    # **private**
    # flag that indicates the removable state of the model
    _canRemove: false

    # **private**
    # flag that allow to differentiate external and triggered saves
    _saveInProgress: false

    # **private**
    # flag that indicates that a closure is in progress, and that disable validations
    _isClosing: false

    # **private**
    # flag that allow to differentiate external and triggered removal
    _removeInProgress: false

    # **private**
    # while the edited object is still not saved on server, we need an id.
    _tempId: null

    # **private**
    # arrays of validators.
    _validators: []

    # **private**
    # array of files that needs to be uploaded
    _pendingUploads: []

    # ** private**
    # the action bar with save, remove and addProperty buttons
    _actionBar: null

    # **private**
    # save button widget
    _saveButton: null

    # **private**
    # remove button widget
    _removeButton: null

    # **private**
    # widget that displays the model's name
    _nameWidget: null

    # **private**
    # widget that displays the model's description
    _descWidget: null

    # **private**
    # description image widget
    _descImageWidget: null

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id, className) ->
      super({tagName: 'div', className:"#{className} view"})
      # creation of a new item type if necessary
      if id?
        @model = @_collection.get(id)
      else 
        @_createNewModel() 
        @_tempId = utilities.generateId()

      @_canSave = false
      @_canRemove = @_tempId is null
      # bind change event to the update of action button bar
      @on('change', () =>
        return unless @_actionBar?
        if @canSave() then @_saveButton.enable() else @_saveButton.disable()
        if @canRemove() then @_removeButton.enable() else @_removeButton.disable()
      )

      @_pendingUploads = []

      # bind to server events
      @bindTo(@_collection, 'add', @_onCreated)
      @bindTo(@_collection, 'update', @_onSaved)
      @bindTo(@_collection, 'remove', @_onRemoved)

    # Returns a unique id. 
    #
    # @return If the edited object is persisted on server, return its id. Otherwise, a temporary unic id.
    getId: () =>
      return if @_tempId isnt null then @_tempId else @model.id

    # Returns the view's title
    #
    # @return the edited object name.
    getTitle: () =>
      return if @_nameWidget? then @_nameWidget.options.value else @model.get('name')

    # Indicates wether or not this object can be removed.
    # When status changed, a `change` event is triggered on the view.
    #
    # @return the removable status of this object
    canRemove: () =>
      return @_canRemove

    # Indicates wether or not this object can be saved.
    # When status changed, a `change` event is triggered on the view.
    #
    # @return the savable status of this object
    canSave: () =>
      return @_canSave and @_pendingUploads.length is 0

    # Returns the view's action bar, and creates it if needed.
    # may be overriden by subclasses to add buttons
    #
    # @return the action bar rendering.
    getActionBar: () =>
      return @_actionBar if @_actionBar?
      # creates the rendering
      @_actionBar = $('<div><a class="save"></a><a class="remove"></a><a class="addProperty"></a></div>')
      # wire the save button
      @_saveButton = @_actionBar.find('.save')
        .attr('title', i18n.tips.save)
        .button(
          icons: 
            primary: 'save small'
          text: false
        )
        .click(@saveModel)
        .data('button')
      # wire the remove button
      @_removeButton = @_actionBar.find('.remove')
        .attr('title', i18n.tips.remove)
        .button(
          icons:
            primary: 'remove small'
          text: false
          disabled: true
        )
        .click(@removeModel)
        .data('button')
      return @_actionBar

    # Method invoked when the view must be closed.
    # @return true if the view can be closed, false to cancel closure
    canClose: () =>
      # allow if we are closing, or if no change found
      return true if @_isClosing or !@canSave()
      $("""<div id="confirmClose-#{@getId()}" title="#{i18n.titles.closeConfirm}">
              <span class="ui-icon question"></span>#{_.sprintf(@_confirmCloseMessage, @model.get 'name')}
            </div>""").dialog(
        modal: true
        close: ->
          $(this).remove()
        buttons: [{
          text: i18n.labels.yes,
          icons:
            primary: 'valid small'
          click: () =>
            # close dialog
            $("#confirmClose-#{@getId()}").dialog('close')
            # and save
            @_isClosing = true
            @saveModel()
        },{
          text: i18n.labels.no,
          icons: {
            primary: 'invalid small'
          }
          click: =>
            # close dialog
            $("#confirmClose-#{@getId()}").dialog('close')
            # and close
            @_isClosing = true
            @trigger 'close'
        },{
          text: i18n.labels.cancel
          icons:
            primary: 'cancel small'
          click: =>
            # just close dialog
            $("#confirmClose-#{@getId()}").dialog('close')
        }]
      )
      # stop closure
      return false

    # Saves the view, by filling edited object with rendering values and asking the server.
    #
    # @param event [event] optionnal click event on the save button
    saveModel: (event = null) =>
      return unless @canSave()
      console.log("save asked for #{@getId()}")
      event?.preventDefault()
      # fill the model and save it
      @_saveInProgress = true
      @_fillModel()
      if @model.get('descImage') isnt @_descImageWidget.options.source
        spec = {file: @_descImageWidget.options.source}
        if @_descImageWidget.options.source is null
          spec.oldName = @model.get('descImage')  
        @_pendingUploads.push(spec)

      # allows subclass to perform specific save operations
      @_specificSave()
      # at last, saves model
      @model.save() 

    # Removes the view, after displaying a confirmation dialog. (the `remove` methods already exists)
    #
    # @param event [event] optional click event on the remove button
    removeModel: (event = null) =>
      event?.preventDefault()
      return unless @canRemove()
      $("""<div id="confirmRemove-#{@getId()}" title="#{i18n.titles.removeConfirm}">
          <span class="ui-icon question"></span>#{_.sprintf @_confirmRemoveMessage, @model.get 'name'}</div>""").dialog
        modal: true,
        close: ->
          $(this).remove()
        buttons: [{
          text: i18n.labels.no
          showText:false
          icons:
            primary: 'invalid small'
          click: ->
            # simply close the dialog
            $(this).dialog('close')
        },{
          text: i18n.labels.yes 
          icons:
            primary: 'valid small'
          click: =>
            # close the dialog and remove the model
            $("\#confirmRemove-#{@getId()}").dialog('close')
            @_removeInProgress = true
            @model.destroy()
        }]

    # The `render()` method is invoked by backbone to display view content at screen.
    render: () =>
      # template rendering
      @$el.empty().append(Milk.render(@_template, @_getRenderData()))

      # creates property for name and description
      @_nameWidget = @$el.find('.name.field').property(
        type: 'string'
        allowNull: false
        change: @_onChange
      ).data('property')

      @_descWidget = @$el.find('.desc.field').property(
        type: 'text'
        allowNull: false
        tooltipFct: i18n.tips.desc
        change: @_onChange
      ).data('property')

      # allows subclass to add specific widgets.
      @_specificRender()
      
      # first rendering filling
      @_fillRendering()

      # for chaining purposes
      return @

    # Enrich the inherited dispose method to free validators.
    dispose: () =>
      validator.dispose() for validator in @_validators
      super()

    # **private**
    # Effectively creates a new model.
    # **Must be overriden by subclasses**
    _createNewModel: () =>
      throw new Error('the _createNewModel() method must be overriden by subclasses')

    # **private**
    # Prepare data to be rendered into the template
    # **Must be overriden by subclasses**
    #
    # @return data filled into the template
    _getRenderData: () =>
      throw new Error('the _createNewModel() method must be overriden by subclasses')

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. Does nothing by default.
    # **May be overriden by subclasses**
    _specificRender: () =>
      # does nothing

    # **private**
    # Allows subclass to add specific errors to be displayed when validating.
    # **May be overriden by subclasses**
    #
    # @return an empty array of errors by default.
    _specificValidate: () =>
      return []

    # **private**
    # Performs view specific save operations, right before saving the model.
    # **May be overriden by subclasses**
    _specificSave: () =>
      # does nothing  

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: () =>
      @model.set('name', @_nameWidget.options.value)
      @model.set('desc', @_descWidget.options.value) if @_descWidget?

      # we only are concerned by setting to null, because image upload is managed by `_onSave`
      @model.set('descImage', null) if @_descImageWidget? and @_descImageWidget.options.source is null
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: () =>
      @_nameWidget.setOption('value', @model.get('name'))
      @_descWidget.setOption('value', @model.get('desc')) if @_descWidget?
      @_createImages()

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: () =>
      comparable = []
      # adds name and description
      comparable.push( 
        name: 'name'
        original: @model.get('name')
        current: @_nameWidget.options.value)
      if @_descWidget?
        comparable.push(
          name: 'description'
          original: @model.get('desc')
          current: @_descWidget.options.value) 
      if @_descImageWidget?
        comparable.push(
          name: 'descImage'
          original: @model.get('descImage')
          current: @_descImageWidget.options.source)
      return comparable

    # **private**
    # Creates LoadableImage for each images of the edited object
    _createImages: () =>
      # the description image
      unless @_descImageWidget?
        @_descImageWidget = @$el.find('.desc.image').loadableImage(
          source: @model.get('descImage')
          change: @_onChange
        ).data('loadableImage')
      else 
        @_descImageWidget.setOption('source', @model.get('descImage'))

    # **private**
    # Re-creates validators, when refreshing the properties.
    # Existing validators are trashed, and validators created for:
    # - name
    _createValidators: () =>
      validator.dispose() for validator in @_validators
      @_validators = []

      # adds a validator for name
      @_validators.push(new validators.String({required: true}, i18n.labels.name, 
        @_nameWidget.element, null, (node) -> node.find('input').val()))

    # **private**
    # Allows to compute the rendering's validity.
    # 
    # @return true if all rendering's fields are valid
    _validate: () =>
      isValid = true;
      errors = []
      # view own validators
      for validator in @_validators 
        errors = errors.concat(validator.validate())

      # allows subclass to add specific errors
      errors = errors.concat(@_specificValidate())

      container = @$el.find('.errors').empty()
      container.append("<p>#{error.msg}</p>") for error in errors
      return errors.length is 0

    # **private**
    # Displays warning dialog when edited object have been removed externally.
    _notifyExternalRemove: () =>
      return if $("#externalRemove-#{@getId()}").length > 0
      $("""<div id="externalRemove-#{@getId()}" title="#{i18n.titles.external}">
              <span class="ui-icon warning"></span>#{_.sprintf(i18n.msgs.externalRemove, @model.get 'name')}
            </div>""").dialog(
        modal: true
        close: ->
          $(this).remove()
        buttons: [{
          text: i18n.labels.ok,
          click: =>
            # just close dialog
            $("#externalRemove-#{@getId()}").dialog('close')
        }]
      )

    # **private**
    # Displays warning dialog when edited object have been modified externally.
    _notifyExternalChange: () =>
      return if $("#externalChange-#{@getId()}").length > 0
      $("""<div id="externalChange-#{@getId()}" title="#{i18n.titles.external}">
              <span class="ui-icon warning"></span>#{_.sprintf(i18n.msgs.externalChange, @model.get 'name')}
            </div>""").dialog(
        modal: true
        close: ->
          $(this).remove()
        buttons: [{
          text: i18n.labels.ok,
          click: =>
            # just close dialog
            $("#externalChange-#{@getId()}").dialog('close')
        }]
      )

    # **private**
    # Change handler, wired to any changes from the rendering.
    # Checks if the edited object effectively changed, and update if necessary the action bar state.
    _onChange: () =>
      # first, rendering validity
      isValid = @_validate()
      hasChanged = false

      if isValid
        # compares rendering and model values
        comparableFields = @_getComparableFields()
        for field in comparableFields
          hasChanged = !(_.isEqual(field.original, field.current))
          if hasChanged
            console.log "field #{field.name} modified"
            break;

      console.log("is valid ? #{isValid} is modified ? #{hasChanged} is new ? #{@_tempId?}")
      @_canSave = isValid and hasChanged
      @_canRemove = @_tempId is null
      # trigger change
      @trigger('change', @)

    # **private**
    # Invoked when a ItemType is created on the server.
    # Triggers the `affectId` event and then call `_onSaved`
    #
    # @param created [Object] the created model
    _onCreated: (created) =>
      return unless @_saveInProgress
      # update the id to allow _onSaved to perform
      @model.id = created.id
      # indicates to perspective that we affected the id.
      @trigger('affectId', @_tempId, @model.id)
      @_tempId = null
      @_onSaved(created)

    # **private**
    # Invoked when a ItemType is saved from the server.
    # Refresh internal and rendering if the saved object corresponds to the edited one.
    #
    # @param saved [Object] the saved model
    _onSaved: (saved) =>
      # takes in account if we updated the edited objet
      return unless saved.id is @model.id
      # if it was a close save, trigger close once again
      if @_isClosing
        console.log "go on with closing #{@getId()}"
        return @trigger('close')

      console.log "object #{@getId()} saved !"
      @_notifyExternalChange() unless @_saveInProgress
      @_saveInProgress = false;

      # updates edited object
      @model = saved

      # rfresh rendering and exiti, or proceed with changes
      return @_fillRendering() unless @_pendingUploads.length > 0

      spec = @_pendingUploads.splice(0, 1)[0]
      @_saveInProgress = true
      if 'oldName' of spec
        # removes existing data
        rheia.imagesService.remove('ItemType', @model.id, spec.oldName, if spec.idx? then spec.idx)
      else
        # upload new file data
        rheia.imagesService.upload('ItemType', @model.id, spec.file, if spec.idx? then spec.idx)
      
        
    # **private**
    # Invoked when a ItemType is removed from the server.
    # Close the view if the removed object corresponds to the edited one.
    #
    # @param removed [Object] the removed model
    _onRemoved: (removed) =>
      # takes in account if we removed the edited objet,
      console.log(">>> removed #{removed.id} (current #{@model.id})")
      return unless removed.id is @model.id
      @_notifyExternalRemove() unless @_removeInProgress
      @_removeInProgress = false;

      @_isClosing = true
      console.log "close the view of #{@getId()} because removal received"
      @trigger('close')

  return BaseEditionView