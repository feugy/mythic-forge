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
  'text!tpl/turnRule.tpl'
  'view/edition/Rule'
  'model/Executable'
], ($, i18n, i18nEdition, template, emptyRule, RuleView, Executable) ->

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
    constructor: (id) ->
      super id, 'turn-rule'
      # on content changes, displays rank.
      @bindTo @model, 'change:rank', @_onRankChange
      console.log "creates turn rule edition view for #{if id? then @model.id else 'a new turn rule'}"

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new Executable _id: i18n.labels.newName, content: emptyRule
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      @_onRankChange()
      # superclass handles description image, name, description and content
      super()

    # **private**
    # Invoked when a model is created on the server.
    # Extends inherited method to bind event handler on new model.
    #
    # @param created [Object] the created model
    _onCreated: (created) =>
      return unless @_saveInProgress
      # unbound from the old model updates
      @unboundFrom @model, 'change:rank'
      # now refresh rendering
      super created
      # bind to the new model
      @bindTo @model, 'change:rank', @_onRankChange

    # **private**
    # Refresh rank displayal when the model's content changed.
    _onRankChange: =>
      rank = @model.rank
      @$el.find('.rank').html if rank then rank else 0