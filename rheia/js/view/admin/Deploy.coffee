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

    # **private**
    # Current developpement version
    _version: null

    # **private**
    # Simple shortcut to rheia administration service singleton
    _service: null

    # The view constructor.
    #
    # @param className [String] css ClassName, set by subclasses
    constructor: (className) ->
      super tagName: 'div', className:'deploy view'

      utils.onRouterReady =>  
        @_service = rheia.adminService
        @bindTo @_service, 'initialized', @render # re-render all when state changed
        @bindTo @_service, 'versionChanged', @_onRefreshVersions
        @bindTo @_service, 'progress', @_onStateChanged
        for method in ['deploy', 'commit', 'rollback', 'createVersion', 'restoreVersion']
          @bindTo @_service, method, @_onError
        @render()

    # The `render()` method is invoked by backbone to display view content at screen.
    render: =>
      super()
      return @ unless @_service?.initialized

      # creates buttons
      @$el.find('a.deploy').button(
        text: true
        icons: 
          primary: 'upload small'
        label: i18n.buttons.deploy
      ).on 'click', (event) =>
        event?.preventDefault()
        @_askVersion i18n.titles.confirmDeploy, i18n.msgs.confirmDeploy, (version) =>
          # triggers deployement
          @_service.deploy version

      @$el.find('a.commit').button(
        text: true
        icons: 
          primary: 'valid small'
        label: i18n.buttons.commit
      ).hide().on 'click', (event) =>
        event?.preventDefault()
        @_service.commit()

      @$el.find('a.rollback').button(
        text: true
        icons: 
          primary: 'invalid small'
        label: i18n.buttons.rollback
      ).hide().on 'click', (event) =>
        event?.preventDefault()
        @_service.rollback()

      @$el.find('.new-version').button(
        text: true
        label: i18n.buttons.createVersion
      ).on 'click', (event) =>
        event?.preventDefault()
        @_askVersion i18n.titles.createVersion, i18n.msgs.createVersion, (version) =>
          # triggers deployement
          @_service.createVersion version

      # displays versions
      @_onRefreshVersions null, @_service.versions(), @_service.current()
      # wire version change
      @$el.find('select').on 'change', =>
        name = @$el.find('select :selected').attr 'value'
        return unless @_version isnt name
        utils.popup i18n.titles.confirmRestore, _.sprintf(i18n.msgs.confirmRestore, name, @_version), 'warning', [
          text: i18n.buttons.cancel
          icon: 'invalid'
          click: =>
            # reselect previous version
            @$el.find('option').removeAttr 'selected'
            @$el.find("option[value='#{@_version}']").attr 'selected', 'selected'
        , 
          text: i18n.buttons.ok
          icon: 'valid'
          click: =>
            @$el.find('select').attr 'disabled', 'disabled'
            @$el.find('.new-version').button 'option', 'disabled', true
            @_service.restoreVersion name
        ]

      @$el.find('.progress').hide()

      # adapt to service current state
      state = null
      if @_service.isDeploying()
        state = 'DEPLOY_START'
      else if @_service.hasDeployed()
        state = 'DEPLOY_END'
      
      if state?
        # defer to let jQuery display rendering, and avoid visual glitch on buttons
        _.defer => @_onStateChanged state 

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
      if err?
        return utils.popup i18n.titles.serverError, _.sprintf(i18n.errors.version, err), 'cancel', [text:i18n.buttons.ok, icons:'valid'] 
      @_version = current
      selector = @$el.find 'select'
      # refresh version selector
      selector.empty()
      html = ''
      for version in versions
        html += "<option value='#{version}' #{if version is current then 'selected'}>#{version}</option>"
      selector.append html
      # enable controls
      @$el.find('select').removeAttr 'disabled'
      @$el.find('.new-version').button 'option', 'disabled', false

    # **private**
    # Deployement state change: update rendering to get in deploy/commit/rollback mode, and
    # update the current state.
    #
    # @param state [String] the new current state
    _onStateChanged: (state) =>
      switch state
        when 'DEPLOY_START', 'COMMIT_START', 'ROLLBACK_START' 
          @_renderProgress()
        when 'COMMIT_END', 'ROLLBACK_END'
          # hide progress stuff and show deploy button
          @$el.find('.progress, .waiting').hide()
          @$el.find('a.deploy').show()
        when 'DEPLOY_END'
          @$el.find('.progress').hide()
          unless err?
            @$el.find('a.deploy').hide()
            if @_service.isDeployer()
              @$el.find('.commit, .rollback').show()
            else
              @$el.find('.waiting').html("#{_.sprintf i18n.labels.waitingCommit, @_service.deployer()}").show()
          return unless @_service.isDeployer()
          # Display a popup to inform user or display error
          popup = utils.popup i18n.titles.deployed, i18n.msgs.deployed, 'warning', [
            text: i18n.buttons.ok
            icon: 'valid'
          ]
        when 'DEPLOY_FAILED'
          @$el.find('.progress').hide()
          @$el.find('a.deploy').show()
        when 'COMMIT_FAILED', 'ROLLBACK_FAILED'
          @$el.find('.progress').hide()
          @$el.find('.commit, .rollback').show()
        when 'VERSION_CREATED', 'VERSION_RESTORED'
          # do nothing
        else 
          @$el.find('.waiting').hide()
          @$el.find('.progress label').html if i18n.labels[state]? then i18n.labels[state] else state

    # **private**
    # Deploy, commit and rollback error handler that displays a information popup
    #
    # @param err [String] error message, or null if no error occured
    _onError: (err) =>
      return unless err?
      @$el.find('select').removeAttr 'disabled'
      @$el.find('.new-version').button 'option', 'disabled', false
      utils.popup i18n.titles.serverError, _.sprintf(i18n.errors.deploy, err), 'cancel', [text:i18n.buttons.ok, icons:'valid']