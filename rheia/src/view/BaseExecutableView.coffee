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
  'utils/utilities'
  'i18n!nls/common'
  'view/BaseEditionView'
], ($, _, utils, i18n, BaseEditionView) ->

  # A base view that brings rule application functionnalities.
  # If an '.apply-rules' button (and its corresponding '.apply-rule-menu') is found in rendering, allows
  # rules resolution and application 
  class BaseExecutableView extends BaseEditionView

    # **private**
    # applicable rule menu
    _menu: null 

    # The view constructor.
    #
    # @param id [String] the edited object's id, null for creation
    # @param className [String] rendering root node Css class.
    constructor: (id, className) ->
      # superclass constructor
      super id, className

    # Extends to add rule application button 
    render: =>
      super()

      # get applicable rules on click
      @$el.find('.apply-rule').button(icons: secondary: 'ui-icon-triangle-1-s').on 'click', (event) => 
        event.preventDefault()
        @_menu.addClass 'open'
        @_resolveRules()
      # hides menu and clear its content
      @_menu = @$el.find '.apply-rule-menu'
      @_menu.on 'click', '> *', @_onExecuteRule
      @_menu.on 'mouseleave click', => 
        @_menu.removeClass 'open'
        @_menu.empty()
      @

    # **private**
    # Resolve applicatble rule on the current model
    _resolveRules: =>
      # use a dedicated closure to avoid multiple request erasures
      ((rid) =>
        # on response, add item to the popup menu
        app.sockets.game.on 'resolveRules-resp', onResolve = (reqId, err, results) =>
          return unless reqId is rid
          # discard listener
          app.sockets.game.removeListener 'resolveRules-resp', onResolve
          @_menu.empty()

          # display error
          if err?
            utils.popup i18n.titles.ruleError, 
              _.sprintf(i18n.errors.resolveRules, utils.instanceName(@model), err),  
              'warning', [text:i18n.buttons.ok, icon:'valid']
          unless results? and !_.isEmpty results
            html = ["<li>#{i18n.labels.noRules}</li>"]
          else
            html = ( 
              for ruleId, result of results
                """<li 
                      data-rule="#{ruleId}" 
                      data-params="#{JSON.stringify result[0].params}"
                    >#{ruleId}</li>"""
            )
          @_menu.append html.join ' '

        # ask on server which rules apply on model
        @_getRuleParameters null, null, (err, actor) => 
          if err?
            @_menu.removeClass 'open'
            return console.log err 
          args = ['resolveRules', rid]
          args.push actor.id if actor?
          args.push @model.id, null
          app.sockets.game.emit.apply app.sockets.game, args
      ) utils.rid()

    # **private**
    # Apply a given rule on the current model  
    _onExecuteRule: (event) =>
      ruleId = $(event.target).closest('li').data 'rule'
      return unless ruleId?
      # use a dedicated closure to avoid multiple request erasures
      ((rid, ruleId, params) =>
        # on response, display potential error
        app.sockets.game.on 'executeRule-resp', onExecute = (reqId, err, results) =>
          return unless reqId is rid
          # discard listener
          app.sockets.game.removeListener 'executeRule-resp', onExecute
          console.log results
          # display error
          if err?
            utils.popup i18n.titles.ruleError, 
              _.sprintf(i18n.errors.executeRule, ruleId, utils.instanceName(@model), err),  
              'warning', [text:i18n.buttons.ok, icons:'valid']

        # ask on server to execute rule
        @_getRuleParameters ruleId, params, (err, actor, params) => 
          return console.log err if err?
          args = ['executeRule', rid, ruleId]
          args.push actor.id if actor?
          args.push @model.id, params or {}
          app.sockets.game.emit.apply app.sockets.game, args
      ) utils.rid(), ruleId, $(event.target).closest('li').data 'params'


    # **private**
    # Invoked to get 'resolveRules' and 'executeRule' parameters: actor or actor/params.
    # For 'resolveRules', returns global current character.
    # For 'executeRules', returns global current character and no parameters.
    # If no global character is found, returns an error and warning popup.
    # Overridable by sub classes. 
    #
    # @param ruleId [String] id of executed rule, null for resolution.
    # @param params [Object] associative array of expected execution parameters, null for resolution.
    # @param callback [Function] process end callback, invoked with arguments:
    # @option callback err [String] an error string, or null if no error occured
    # @option callback actor [Object] resolving/executing actor. May by null.
    # @option callback params [Object] execution parameter values. May by empty.
    _getRuleParameters: (ruleId, params, callback) =>
      # invoke if possible
      return callback null, app.embodiment, {} if app.embodiment?
      utils.popup i18n.titles.ruleError, i18n.msgs.noEmbodiment, 'warning', [text:i18n.buttons.ok, icon:'valid']
      callback "no embodiment"