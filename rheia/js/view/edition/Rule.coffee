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
  'text!tpl/new-rule-coffee.tpl'
  'text!tpl/new-rule-js.tpl'
  'view/edition/Script'
  'model/Executable'
], ($, i18n, i18nEdition, template, emptyRuleCoffee, emptyRuleJs, ScriptView, Executable) ->

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
    # @param lang [String] created object language, or null for an opening.
    # @param className [String] optional CSS className, used by subclasses
    constructor: (id, lang= null, className = 'rule') ->
      super id, lang, className
      # on content changes, updates metadatas also
      @bindTo @model, 'change:meta', @_onMetaChange
      console.log "creates rule edition view for #{if id? then @model.id else 'a new rule'}"
    
    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new Executable lang: @_lang, content: if @_lang is 'js' then emptyRuleJs else emptyRuleCoffee

    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      @_onMetaChange()
      # superclass handles name and content
      super()

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      data = super()
      data.title = _.sprintf i18n.titles.rule, @model.id
      data
      
    # **private**
    # Invoked when a model is created on the server.
    # Extends inherited method to bind event handler on new model.
    #
    # @param created [Object] the created model
    _onCreated: (created) =>
      return unless @_saveInProgress
      # unbound from the old model updates
      @unboundFrom @model, 'change:meta'
      # now refresh rendering
      super created
      # bind to the new model
      @bindTo @model, 'change:meta', @_onMetaChange

    # **private**
    # Refresh category and active displayal when the model's content changed.
    _onMetaChange: =>
      return unless @model.meta?
      category = @model.meta.category
      @$el.find('.category').html if category then category else i18n.labels.noRuleCategory
      @$el.toggleClass 'inactive', !@model.meta.active