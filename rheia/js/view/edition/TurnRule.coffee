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
  'text!tpl/turnRule.html'
  'text!tpl/new-turnRule-coffee.tpl'
  'text!tpl/new-turnRule-js.tpl'
  'view/edition/Rule'
  'model/Executable'
], ($, i18n, i18nEdition, template, emptyRuleCoffee, emptyRuleJs, RuleView, Executable) ->

  i18n = $.extend true, i18n, i18nEdition

  # Displays and edit a Rule on edition perspective
  class TurnRuleView extends RuleView

    # **private**
    # mustache template rendered
    _template: template

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    # @param lang [String] created object language, or null for an opening.
    constructor: (id, lang) ->
      super id, lang, 'turn-rule'
      # on content changes, displays rank.
      console.log "creates turn rule edition view for #{if id? then @model.id else 'a new turn rule'}"

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new Executable lang: @_lang, content: if @_lang is 'js' then emptyRuleJs else emptyRuleCoffee

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      data = super()
      data.title = _.sprintf i18n.titles.turnRule, @model.id
      data

    # **private**
    # Refresh rank and active displayal when the model's content changed.
    _onMetaChange: =>
      @$el.find('.rank').html @model.meta?.rank or 0
      @$el.toggleClass 'inactive', !@model.meta?.active