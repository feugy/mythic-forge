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
  'text!tpl/rule.html'
  'text!tpl/rule.tpl'
  'view/edition/Script'
  'model/Executable'
], ($, i18n, i18nEdition, template, emptyRule, ScriptView, Executable) ->

  i18n = $.extend true, i18n, i18nEdition

  # Displays and edit a Rule on edition perspective
  class RuleView extends ScriptView

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeRuleConfirm

    # The view constructor.
    #
    # @param id [String] the edited object's id, of null for a creation.
    # @param className [String] optional CSS className, used by subclasses
    constructor: (id, className = 'rule') ->
      super id, className
      # on content changes, displays category and active status
      @bindTo @model, 'change:category', @_onCategoryChange
      @bindTo @model, 'change:active', @_onActiveChange
      console.log "creates rule edition view for #{if id? then @model.id else 'a new rule'}"
    
    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new Executable _id: i18n.labels.newName, content: emptyRule

    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      @_onCategoryChange()
      @_onActiveChange()
      # superclass handles name and content
      super()

    # **private**
    # Invoked when a model is created on the server.
    # Extends inherited method to bind event handler on new model.
    #
    # @param created [Object] the created model
    _onCreated: (created) =>
      return unless @_saveInProgress
      # unbound from the old model updates
      @unboundFrom @model, 'change:category'
      @unboundFrom @model, 'change:active'
      # now refresh rendering
      super created
      # bind to the new model
      @bindTo @model, 'change:category', @_onCategoryChange
      @bindTo @model, 'change:active', @_onActiveChange

    # **private**
    # Refresh category displayal when the model's content changed.
    _onCategoryChange: =>
      category = @model.category
      @$el.find('.category').html if category then category else i18n.buttons.noRuleCategory

    # **private**
    # Refresh active displayal when the model's content changed.
    _onActiveChange: =>
      @$el.toggleClass 'inactive', !@model.active