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
  'i18n!nls/common'
  'i18n!nls/edition'
  'text!tpl/script.html'
  'text!tpl/script.tpl'
  'utils/validators'
  'view/BaseEditionView'
  'model/Executable'
  'widget/advEditor'
], ($, i18n, i18nEdition, template, emptyScript, validators, BaseEditionView, Executable) ->

  i18n = $.extend true, i18n, i18nEdition

  # Displays and edit a Script on edition perspective
  class ScriptView extends BaseEditionView

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: Executable.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeScriptConfirm

    # **private**
    # widget that allows content edition
    _editorWidget: null

    # **private**
    # language used, for creation only
    _lang: null

    # The view constructor.
    #
    # @param id [String] the edited object's id, or null for a creation.
    # @param lang [String] created object language, or null for an opening.
    # @param className [String] optional CSS className, used by subclasses
    constructor: (id, @_lang = null, className = 'script') ->
      super id, className
      # on content changes, displays category and active status
      console.log "creates script edition view for #{if id? then @model.id else 'a new script'}"
    
    # Called by the TabPerspective each time the view is showned.
    shown: =>
      @_editorWidget?.resize()
      
    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new Executable content: emptyScript, lang: @_lang

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      # superclass handles description image
      super()
      @model.content = @_editorWidget.options.text
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      # superclass handles description image
      super()
      @_editorWidget.setOption 'text', @model.content
      @_onChange()

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      title: _.sprintf i18n.titles.script, @model.id
      lang: i18n.labels[@model.lang]
      i18n: i18n

    # **private**
    # Performs view specific rendering operations.
    # Creates the editor and category widgets.
    _specificRender: =>
      super()
      @_editorWidget = @$el.find('.content').advEditor(
        mode: i18n.constants.extToMode[@model.lang]
      ).on('change', @_onChange).data 'advEditor'

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      # superclass handles description image, name and description. We add content.
      comparable = super()
      comparable.push
        name: 'content'
        original: @model.content
        current: @_editorWidget.options.text
      comparable