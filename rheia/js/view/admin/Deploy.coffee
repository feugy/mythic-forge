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
  'i18n!nls/common'
  'i18n!nls/administration'
  'text!tpl/deployView.html'
  'utils/utilities'
  'utils/validators'
], ($, _, Backbone, i18n, i18nAdmin, template, utils, validators) ->

  i18n = $.extend true, i18n, i18nAdmin

  # The deploy view displays a set of tools relative to the game client deployement
  class Perspective extends Backbone.View
    
    # **private**
    # mustache template rendered
    _template: template

    # The view constructor.
    #
    # @param className [String] css ClassName, set by subclasses
    constructor: (className) ->
      super tagName: 'div', className:'deploy view'
      @bindTo rheia.adminService, 'state', @render # re-render all when state changed
      @bindTo rheia.adminService, 'versions', @_onRefreshVersions
      @bindTo rheia.adminService, 'deploy', @_onDeployed
      @bindTo rheia.adminService, 'commit', @_onEndDeploy
      @bindTo rheia.adminService, 'rollback', @_onEndDeploy
      @bindTo rheia.adminService, 'progress', (state, step) =>
        @$el.find('.progress label').html if i18n.labels[state]? then i18n.labels[state] else state

    # The `render()` method is invoked by backbone to display view content at screen.
    render: =>
      super()
      # creates buttons
      @$el.find('a.deploy').button(
        text: true
        icons: 
          primary: 'upload small'
        label: i18n.buttons.deploy
      ).on 'click', @_onDeploy

      @$el.find('a.commit').button(
        text: true
        icons: 
          primary: 'valid small'
        label: i18n.buttons.commit
      ).hide().on 'click', (event) =>
        event?.preventDefault()
        @_renderProgress()
        rheia.adminService.commit()

      @$el.find('a.rollback').button(
        text: true
        icons: 
          primary: 'invalid small'
        label: i18n.buttons.rollback
      ).hide().on 'click', (event) =>
        event?.preventDefault()
        @_renderProgress()
        rheia.adminService.rollback()

      @$el.find('.progress').hide()
      # get the version list
      rheia.adminService.versions()

      # check if no deployement in progress
      if rheia.adminService.isDeploying()
        @_renderProgress()
      else if rheia.adminService.hasDeployed()
        @_onDeployed null

      # for chaining purposes
      @

    # **private**
    # Provides template data for rendering
    #
    # @return an object used as template data 
    _getRenderData: => {
        i18n: i18n
      }

    # **private**
    # Hide buttons and render a progress bar
    _renderProgress: =>
      @$el.find('.commit, .rollback, a.deploy').hide()
      @$el.find('.progress').css 'display', 'inline-block'

    # **private**
    # Display a modal window to choose a version name.
    #
    # @param title [String] the popup title
    # @param message [String] the popup message
    # @param callback [Function] callback invoked when version was choosen
    # @option callback version [String] the version choosen
    _askVersion: (title, message, callback) => 
      # Display a popup to confirm deployement
      popup = utils.popup title, message, 'question', [
        text: i18n.buttons.cancel
        icon: 'invalid'
        click: =>
          validator.dispose()
      ,
        text: i18n.buttons.ok
        icon: 'valid'
        click: =>
          validator.dispose()
          callback field.val()
      ], 0, 'deploy-confirmation-popup'

      field = $('<input type="text"/>').on('validation', (event, errors) ->
        report = popup.find '.errors'
        # empty and refill error report
        report.empty()
        report.append _.pluck(errors, 'msg').join '<br/>' if Array.isArray errors
        # update ok button state
        popup.dialog('widget').find('button:nth-child(2)').button 'option', 'disabled', errors?.length > 0
      ).appendTo popup

      validator = new validators.String 
        required: true
        spacesAllowed: false
        requiredError: i18n.errors.missingVersion
        spacesNotAllowedError: i18n.errors.versionWithSpace
      , '', field, 'keyup'
      validator.validate()

      popup.append '<p class="errors"></p>'

    # **private**
    # Invoked when the game client version list was retrieved. refresh rendering
    #
    # @param err [String] server error
    # @param versions [Array] a list (that may be empty) of game client version
    _onRefreshVersions: (err, versions, current) =>
      return if err?
      selector = @$el.find 'select'
      selector.empty()
      html = ''
      for version in versions
        html += "<option value='#{version}' #{if version is current then 'selected'}>#{version}</option>"
      selector.append html

    # **private**
    # Game client deployement handler. Ask a confirmation an triggers deployement.
    #
    # @param event [event] the button click cancelled event.
    _onDeploy: (event) =>
      event?.preventDefault()
      @_askVersion i18n.titles.confirmDeploy, i18n.msgs.confirmDeploy, (version) =>
        # triggers deployement
        @_renderProgress()
        rheia.adminService.deploy version

    # **private**
    # Deployement end handler: displays possible error and activate commit/rollback buttons 
    #
    # @param err [String] error string. null if no error occured
    _onDeployed: (err) =>
      message = if err? then _.sprintf i18n.msgs.deployError, err else i18n.msgs.deployed
      icon = if err? then 'cancel' else 'warning'
      @$el.find('.progress').hide()
      unless err?
        @$el.find('.commit, .rollback').show()
        @$el.find('a.deploy').hide()
      # Display a popup to inform user or display error
      popup = utils.popup i18n.titles.deployed, message, icon, [
        text: i18n.buttons.ok
        icon: 'valid'
      ]

    # **private**
    # End deployement handler that update version list and show deloy button
    _onEndDeploy: =>
      # update versions and show deploy button
      rheia.adminService.versions()
      @$el.find('.progress').hide()
      @$el.find('a.deploy').show()