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
  'backbone'
  'utils/utilities'
  'i18n!nls/common'
], ($, _, Backbone, utils, i18n) ->

  # Base class for views used in TabPerspective
  # Must be overriden and some methods and attributes has to be provided by subclasses
  class BaseView extends Backbone.View

    # the edited object
    model: null    

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
    _confirmCloseMessage: i18n.msgs.closeConfirm

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
    # flag to differentiate creation from update
    _isNew: false

    # The view constructor.
    #
    # @param id [String] the edited object's id.
    # @param className [String] the edited object's className.
    constructor: (id, className) ->
      super tagName: 'div', className:"#{className} view"
      # creation of a new item type if necessary
      @model = @_collection.get id
      @_isNew = false
      unless @model?
        @_createNewModel()
        @model.set 'id', id
        @_isNew = true

      @_canSave = false
      @_canRemove = !@_isNew

      # bind to server events
      @bindTo @_collection, 'add', @_onCreated
      @bindTo @model, 'update', @_onSaved
      @bindTo @_collection, 'remove', @_onRemoved
      @bindTo app.router, 'serverError', @_onServerError

    # Returns the view's title
    #
    # @param confirm [Boolean] true to get the version of the title for confirm popups. Default to false.
    # @return the edited object name.
    getTitle: (confirm = false) => throw new Error 'getTitle() must be implemented'

    # Indicates wether or not this object can be removed.
    # When status changed, a `change` event is triggered on the view.
    #
    # @return the removable status of this object
    canRemove: => @_canRemove

    # Indicates wether or not this object can be saved.
    # When status changed, a `change` event is triggered on the view.
    #
    # @return the savable status of this object
    canSave: => @_canSave

    # Method invoked when the view must be closed.
    # @return true if the view can be closed, false to cancel closure
    canClose: =>
      # allow if we are closing, or if no change found
      return true if @_isClosing or !@canSave()
      utils.popup i18n.titles.closeConfirm, _.sprintf(@_confirmCloseMessage, @getTitle true), 'question', [
        text: i18n.buttons.yes
        icon: 'valid'
        click: =>
          # save
          @_isClosing = true
          @saveModel()
      ,
        text: i18n.buttons.no
        icon: 'invalid'
        click: =>
          # just close view
          @_isClosing = true
          @trigger 'close'
      ,
        text: i18n.buttons.cancel
        icon: 'cancel'
      ], 2
      # stop closure
      false

    # Saves the view, by filling edited object with rendering values and asking the server.
    #
    # @param event [event] optionnal click event on the save button
    saveModel: (event = null) =>
      return unless @canSave()
      console.log "save asked for #{@model.id}"
      event?.preventDefault()
      # fill the model and save it
      @_saveInProgress = true
      @_fillModel()
      # allows subclass to perform specific save operations
      args = @_specificSave()
      # and at last, saves model
      @model.save null, args

    # Removes the view, after displaying a confirmation dialog. (the `remove` methods already exists)
    #
    # @param event [event] optional click event on the remove button
    removeModel: (event = null) =>
      event?.preventDefault()
      return unless @canRemove()
      utils.popup i18n.titles.removeConfirm, _.sprintf(@_confirmRemoveMessage, @getTitle true), 'question', [
        text: i18n.buttons.no
        icon: 'invalid'
      ,
        text: i18n.buttons.yes
        icon: 'valid'
        click: =>
          # destroy model
          @_removeInProgress = true
          @model.destroy()
      ]

    # The `render()` method is invoked by backbone to display view content at screen.
    render: =>
      # template rendering
      super()

      # allows subclass to add specific widgets.
      @_specificRender()

      # first rendering filling
      @_fillRendering()

      # for chaining purposes
      @

    # Called by the TabPerspective each time the view is showned.
    shown: =>

    # **private**
    # Effectively creates a new model.
    # **Must be overriden by subclasses**
    _createNewModel: => throw new Error '_createNewModel() method must be implemented'

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. Does nothing by default.
    # **May be overriden by subclasses**
    _specificRender: =>
      # does nothing

    # **private**
    # Performs view specific save operations, right before saving the model.
    # **May be overriden by subclasses**
    #
    # @return optionnal arguments for the `save` Backbone method.
    _specificSave: =>
      # does nothing  

    # **private**
    # **Must be overriden by subclasses**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: => throw new Error '_fillModel() must be implemented'
      
    # **private**
    # Updates rendering with values from the edited object.
    # **Must be overriden by subclasses**
    _fillRendering: => throw new Error '_fillRendering() must be implemented'

    # **private**
    # Displays warning dialog when edited object have been removed externally.
    _notifyExternalRemove: () =>
      return if $("#externalRemove-#{@model.id}").length > 0
      utils.popup i18n.titles.external, 
        _.sprintf(i18n.msgs.externalRemove, @model.id), 
        'warning', 
        [text: i18n.buttons.ok],
        0,
        "externalRemove-#{@model.id}"

    # **private**
    # Displays warning dialog when edited object have been modified externally.
    #
    # @param saved [Object] the received values from server
    _notifyExternalChange: (saved) =>
      return if $("#externalChange-#{@model.id}").length > 0
      utils.popup i18n.titles.external, 
        _.sprintf(i18n.msgs.externalChange, @model.id), 
        'warning',
        [text: i18n.buttons.ok], 
        0,
        "externalChange-#{@model.id}"

    # **private**
    # Displays error dialog when current server operation failed on edited object.
    #
    # @param err [String] server error
    _notifyServerError: (err) =>
      return if $("#serverError-#{@model.id}").length > 0
      msgKey = if @_saveInProgress then i18n.msgs.saveFailed else i18n.msgs.removeFailed
      err = if typeof err is 'object' then err.message else err
      utils.popup i18n.titles.serverError, _.sprintf(msgKey, @model.id, err), 'cancel', [text: i18n.buttons.ok]

    # **private**
    # Change handler, wired to any changes from the rendering.
    # May be extended to add validation and specific change detection.
    # triggers the change event.
    #
    # **May be overriden by subclasses**
    _onChange: =>
      @_canRemove = !@_isNew
      # trigger change
      @trigger 'change', @

    # **private**
    # Invoked when a model is created on the server.
    #
    # @param created [Object] the created model
    _onCreated: (created) =>
      return unless @_saveInProgress
      # update view title
      @$el.find('> h1').html @_getRenderData()?.title
      # now refresh rendering
      @_isNew = false
      @_onSaved created


    # **private**
    # Invoked when a model is saved from the server.
    # Refresh internal and rendering if the saved object corresponds to the edited one.
    #
    # @param saved [Object] the saved model
    _onSaved: (saved) =>
      # takes in account if we updated the edited objet
      return unless saved.id is @model.id
      # if it was a close save, trigger close once again
      if @_isClosing
        console.log "go on with closing #{@model.id}"
        return @trigger 'close'

      console.log "object #{@model.id} saved !"
      @_notifyExternalChange saved unless @_saveInProgress
      @_saveInProgress = false

      # updates edited object
      @model = saved

      # refresh rendering
      @_fillRendering()

        
    # **private**
    # Invoked when a model is removed from the server.
    # Close the view if the removed object corresponds to the edited one.
    #
    # @param removed [Object] the removed model
    _onRemoved: (removed) =>
      # takes in account if we removed the edited objet, and if their isn't any id change
      return unless removed.id is @model.id and !@_isNew
      @_notifyExternalRemove() unless @_removeInProgress
      @_removeInProgress = false;

      @_isClosing = true
      console.log "close the view of #{@model.id} because removal received"
      @trigger 'close'

    # **private**
    # Invoked when a server operation failed.
    # Displays a warning popup if the error concerns the current model.
    #
    # @param removed [Object] the removed model
    _onServerError: (err, details) =>
      return unless _(details.method).startsWith "#{@model._className}.sync"
      
      # the current operation failed
      if (details.id is @model.id) and (@_saveInProgress or @_removeInProgress)
        # displays error.
        @_notifyServerError err
        @_saveInProgress = false
        @_removeInProgress = false