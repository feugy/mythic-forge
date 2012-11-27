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
  'model/Executable'
  'i18n!nls/common'
  'i18n!nls/administration'
  'text!tpl/turnsView.html'
  'utils/utilities'
], ($, _, Backbone, Executable, i18n, i18nAdmin, template, utils) ->

  i18n = $.extend true, i18n, i18nAdmin

  # The turns view displays the ordered list of turn rules, and allow to trigger turns
  class Turns extends Backbone.View
    
    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # rules currently displayed
    _rules: []

    # **private**
    # button to trigger turns.
    _triggerButton: null

    # **private**
    # Turn in progress indicator
    _turnInProgress: false

    # The view constructor.
    #
    # @param className [String] css ClassName, set by subclasses
    constructor: (className) ->
      super tagName: 'div', className:'turns view'

      @_turnInProgress = false

      @bindTo Executable.collection, 'reset add remove update change:name change:ranke', @_onResetList

      utils.onRouterReady =>  
        # retrieve rules
        Executable.collection.fetch()  
        rheia.sockets.admin.on 'turns', @_onTurnsEvent

    # The `render()` method is invoked by backbone to display view content at screen.
    render: =>
      super()
      
      @_triggerButton = @$el.find('a.trigger').button(
        text: true
        label: i18n.buttons.triggerTurn
      ).on('click', (event) =>
        # trigger manually the turn
        event?.preventDefault()
        return if @_turnInProgress
        console.info 'manually triggers a turn...'
        rheia.sockets.admin.emit 'triggerTurn'
      ).data 'button'

      # for chaining purposes
      @

    # **private**
    # Provides template data for rendering
    #
    # @return an object used as template data 
    _getRenderData: => {i18n: i18n}

    # **private**
    # Creates rule rendering inside the list. Make an li with a checkbox and a status label inside it.
    #
    # @param rule [Object] the displayed turn rule
    # @return a string containing the rendering for a given rule
    _renderRule: (rule) =>
      "<li class='#{md5 rule.name}'><input type='checkbox' disabled/>#{rule.name}</li>"

    # **private**
    # Turn progression handler.
    # `begin` and `end` events are always triggered once each other.
    # For each turn rule, `rule` will occured one time indicating the rule beginning.
    # For each turn rule, `success` or `failure` will occured one time, with error message for `failure`.
    # An `error` event can also be received, with executable (not rule) name in second parameter.
    # It will not be correlated with an existing rule.
    #
    # @param state [String] turn state: `begin`, `end`, `success` and `failure` event are handled
    # @param name [String] the concerned rule name
    # @param err [String] an optionnal error message
    _onTurnsEvent: (state, name, err) =>
      switch state
        when 'begin'
          console.info 'turn begins'
          @_turnInProgress = true
          @_triggerButton._setOption 'disabled', true
          @$el.find(".list > *").removeClass 'failure success'
          @$el.find('.errors').empty()
          @$el.find(".list input").removeAttr 'checked'
        when 'end'
          console.info 'turn end'
          @_triggerButton._setOption 'disabled', false
          @_turnInProgress = false
        when 'rule'
          @$el.find(".#{md5 name}").addClass 'progress'
        when 'success'
          @$el.find(".#{md5 name}").removeClass('progress').addClass 'success'
          @$el.find(".#{md5 name} input").attr 'checked', 'checked'
        when 'failure'
          @$el.find(".#{md5 name}").removeClass('progress').addClass 'failure'
          @$el.find('.errors').append "<div>#{err}</div>"
        when 'error'
          @$el.find('.errors').append "<div class='fatal'>#{err}</div>"

    # **private**
    # Build turn ordered list when the Executable collection changed
    _onResetList: =>
      @_rules = (rule for rule in Executable.collection.models when rule.kind is 'TurnRule' and rule.name? and rule.active)
      # turn rules are organized by their rank
      @_rules = _.chain(@_rules).map((rule) -> rank:rule.rank, value:rule).sortBy('rank').pluck('value').value()

      list = ''
      list += @_renderRule rule for rule in @_rules
      @$el.find('.list').html list
      
      @$el.find('.errors').empty()