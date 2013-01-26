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
  'backbone'
  'model/Player'
  'i18n!nls/common'
  'text!tpl/layout.html'
], ($, Backbone, Player, i18n, template) ->

  # The edition perspective manages types, rules and maps
  class Layout extends Backbone.View

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # the perspective container
    _container: null

    # The view constructor.
    constructor: () ->
      super tagName: 'div', className:'layout'
      @bindTo Backbone.history, 'route', @_onRoute
      @bindTo Player.collection, 'connectedPlayersChanged', @_onConnectedPlayersChanged
      @bindTo app.adminService, 'progress', @_onDeployementStateChanged
      @bindTo app.adminService, 'state', =>
        # a deployement is in progress
        if app.adminService.isDeploying() or app.adminService.hasDeployed()
          @_onDeployementStateChanged 'DEPLOY_START'

    # the render method, which use the specified template
    render: =>
      $('body > .loader').remove()
      super()
      @_container = @$el.find '.container'
      @$el.find('header a').each -> 
        $(this).button
          text: false
          icons:
            primary: "ui-icon #{$(this).attr('class')}"

      @$el.find('a.logout').button(
        label: i18n.buttons.logout
        text: true
        icons:
          primary: "ui-icon small logout"
      ).click (event) =>
        event?.preventDefault()
        app.router.trigger 'logout'

      # for chaining purposes
      @

    # Empties layout's content a display loading animation
    #
    # @param title [String] the new title used for the layout
    loading: (title) =>
      # detach previous content to avoid its destruction
      @_container.children().detach()
      @$el.find('.loader').show()
      @$el.find('header h1').text title

    # Hides the loader and put content inside the container.
    #
    # @param content [jQuery] the content put inside layout
    show: (content) =>
      @_container.append content
      @$el.find('.loader').hide()

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      i18n: i18n

    # **private**
    # Route handler: activate the corresponding button
    #
    # @param history [Backbone.History] the history manager
    # @param handler [String] the ran handler
    _onRoute: (history, handler) =>
      @$el.find('header a').removeClass('active').filter("[data-route='/#{handler}']").addClass 'active'

    # **private**
    # Deployement state change handler. Displays de "deployement in progress indicator", until commit end or rollback
    #
    # @param state [String] deployement new state
    _onDeployementStateChanged: (state) =>
      switch state
        when 'DEPLOY_START'
          @$el.find('.deployement').css 'visibility', 'visible'
        when 'COMMIT_END', 'ROLLBACK_END', 'DEPLOY_FAILED'
          @$el.find('.deployement').css 'visibility', 'hidden'

    # **private**
    # Handler that updates rendering when players are joining or leaving.
    _onConnectedPlayersChanged: =>
      @$el.find('.connected i').html Player.collection.connected.length
