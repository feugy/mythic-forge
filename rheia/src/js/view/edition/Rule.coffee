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
  'backbone'
  'i18n!nls/edition'
  'text!view/edition/template/Rule.html'
  'view/edition/BaseEditionView'
  'model/Executable'
], ($, Backbone, i18n, template, BaseEditionView, Executable) ->

  i18n = $.extend(true, {}, i18n)

  # Displays and edit a Rule on edition perspective
  class RuleView extends BaseEditionView

    # **private**
    # name of the model class
    _modelClassName: 'Executable'

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # name of the model attribute that holds name.
    _nameAttribute: '_id'

    # **private**
    # models collection on which the view is bound
    _collection: Executable.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeRuleConfirm
    
    # **private**
    # close popup confirmation text, that can take the edited object's name in parameter
    _confirmCloseMessage: i18n.msgs.closeConfirm

    # **private**
    # widget that allows content edition
    _editorWidget: null

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id) ->
      super(id, 'rule')
      console.log("creates rule edition view for #{if id? then @model.id else 'a new rule'}")

    # **private**
    # Effectively creates a new model.
    _createNewModel: () =>
      @model = new Executable({_id: i18n.labels.newName, content:''})

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: () =>
      # superclass handles description image, name and description
      super()
      @model.set('content', @_editorWidget.val().replace(/\u000A/g, '\r\n'))
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: () =>
      # superclass handles description image, name and description
      super()
      @_editorWidget.val(@model.get('content'))
      @_onChange()

    # **private**
    # Performs view specific save operations, right before saving the model.
    # Specify new name if name changed
    #
    # @return optionnal attributes that may be specificaly saved. Null or undefined to save all model
    _specificSave: () =>
      if @_tempId?
        @model.set('_id', @_nameWidget.options.value)
        # we need to unset id because it allows Backbone to differentiate creation from update
        @model.id = null
      else if @_nameWidget.options.value isnt @model.id 
        # keeps the new id to allow tab renaming
        @_newId = @_nameWidget.options.value
        return {newId: @_nameWidget.options.value}

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: () =>
      # data needed by the template
      return {
        i18n: i18n
      }

    # **private**
    # Performs view specific rendering operations.
    # Creates the editor widget.
    _specificRender: () =>
      @_editorWidget = @$el.find('textarea').keyup(@_onChange)

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: () =>
      # superclass handles description image, name and description. We add content.
      comparable = super()
      comparable.push(
        name: 'content'
        original: @model.get('content')
        current: @_editorWidget.val().replace(/\u000A/g, '\r\n')
      )
      return comparable

  return RuleView