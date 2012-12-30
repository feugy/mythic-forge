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

# configure requireJs
requirejs.config  
  paths:
    'ace': 'lib/ace-1.0-min'
    'async': 'lib/async-0.1.22-min'
    'backbone': 'lib/backbone-0.9.2-min'
    'coffeescript': 'lib/coffee-script-1.4.0-min'
    'hogan': 'lib/hogan-2.0.0-min'
    'hotkeys': 'lib/jquery-hotkeys-min'
    'html5slider': 'lib/html5slider-min'
    'jquery': 'lib/jquery-1.8.3-min'
    'jquery-ui': 'lib/jquery-ui-1.9.2-min'
    'jquery-punch': 'lib/jquery-punch-0.2.2-min'
    'i18n': 'lib/i18n-2.0.1-min'
    'queryparser': 'lib/queryparser-1.2.0-min'
    'md5': 'lib/md5-2.2-min'
    'moment': 'lib/moment-1.7.0-min'
    'mousewheel': 'lib/jquery-mousewheel-3.0.6-min'
    'nls': '../nls'
    'numeric': 'lib/jquery-ui-numeric-1.2-min'
    'socket.io': 'lib/socket.io-0.9.11-min'
    'text': 'lib/text-2.0.0-min'
    'timepicker': 'lib/jquery-timepicker-addon-1.0.1-min'
    'tpl': '../template'
    'transit': 'lib/jquery-transit-0.9.9-min'
    'underscore': 'lib/underscore-1.3.3-min'
    'underscore.string': 'lib/underscore.string-2.2.0rc-min'
    'utf8': 'lib/utf8'
    # shim for rules
    'mongodb': 'lib/shim/mongodb'
    
  shim:
    'ace/ace':
      exports: 'ace'
    'async': 
      exports: 'async'
    'backbone': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'hogan': 
      exports: 'Hogan'
    'hotkeys':
      deps: ['jquery']
    'jquery': 
      exports: '$'
    'jquery-ui':
      deps: ['jquery']
    'jquery-punch':
      deps: ['jquery']
    'queryparser':
      exports: 'QueryParser'
    'numeric':
      deps: ['jquery-ui']
    'moment':
      exports: 'moment'
    'mousewheel':
      deps: ['jquery']
    'socket.io': 
      exports: 'io'
    'timepicker':
      deps: ['jquery-ui']
    'transit':
      deps: ['jquery']
    'underscore': 
      exports: '_'
    'utf8':
      exports: 'UTF8'

# initialize rheia global namespace
window.rheia = {}

# Mapping between socket.io error reasons and i18n error messages
errorMapping = 
  kicked: 'disconnected'
  disconnected: 'networkFailure'
  'Wrong credentials': 'wrongCredentials'
  'Missing credentials': 'wrongCredentials'
  'Expired token': 'expiredToken'
  unauthorized: 'insufficientRights'
  'Deployment in progress': 'deploymentInProgress'
  '^.* not authorized$': 'clientAccessDenied'

define [
  'underscore'
  'jquery' 
  'socket.io'
  'async'
  'backbone'
  'view/Login'
  'i18n!nls/common'
  'utils/utilities'
  'service/ImagesService'
  'service/SearchService' 
  'service/AdminService' 
  'view/admin/Perspective'
  'view/edition/Perspective'
  'view/authoring/Perspective'
  'view/moderation/Perspective'
  'view/Layout'
  # unwired dependencies
  'utils/extensions'
  'jquery-ui'
  'jquery-punch' 
  'numeric' 
  'transit'
  'timepicker'
  'hotkeys'
  'mousewheel'
  'md5'
  'html5slider'

], (_, $, io, async, Backbone, LoginView, i18n, utils, ImagesService, SearchService, AdminService, 
  AdminPerspective, EditionPerspective, AuthoringPerspective, ModerationPerspective, LayoutView) ->

  version = parseInt $.browser.version
  return $('.disclaimer').show() unless ($.browser.mozilla and version >= 14) or 
    ($.browser.webkit and version >= 530) or
    ($.browser.chrome and version >= 20)
  
  # simple flag to avoid loading multiple perspective at the same time
  perspectiveLoading = false
  isLoggingOut = false
  connected = false

  $(window).on 'beforeunload', () ->
    isLoggingOut = true
    undefined

  # different namespaces that ca be used to communicate qith server
  rheia.sockets =
    game: null
    admin: null
    updates: null

  # the connect function will try to connect with server. 
  # 
  # @param token [String] the autorization token, obtained during authentication
  # @param callback [Function] invoked when all namespaces have been connected.
  # @param errorCallback [Function] invoked when connection cannot be established, or is lost:
  # @option errorCallback err [String] the error detailed case, or null if no error occured
  connect = (token, callback, errorCallback) ->
    isLoggingOut = false
    connected = true

    # wire logout facilities
    rheia.router.on 'logout', => 
      localStorage.removeItem 'rheia.token'
      isLoggingOut = true
      socket.emit 'logout'
      rheia.router.navigate 'login', trigger: true

    socket = io.connect conf.apiBaseUrl, {query:"token=#{token}"}

    socket.on 'error', (err) ->
      errorCallback err if connected

    socket.on 'disconnect', (reason) ->
      connected = false 
      return if isLoggingOut
      errorCallback if reason is 'booted' then 'kicked' else 'disconnected'

    socket.on 'connect', -> 
      # On connection, retrieve current connected player immediately
      socket.emit 'getConnected', (err, player) =>
        # stores the token to allow re-connection
        rheia.player = player
        localStorage.setItem 'rheia.token', player.token
        # update socket.io query to allow reconnection with new token value
        socket.socket.options.query = "token=#{player.token}"

      names = Object.keys rheia.sockets

      async.forEach names, (name, next) ->
        rheia.sockets[name] = socket.of "/#{name}"
        rheia.sockets[name].on 'connect', next
        rheia.sockets[name].on 'connect_failed', next
      , (err) ->
        return errorCallback err if err?
        callback()

  class Router extends Backbone.Router

    # Object constructor.
    #
    # For links that have a route specified (attribute data-route), prevent link default action and
    # and trigger route navigation.
    #
    # Starts history tracking in pushState mode
    constructor: ->
      super()
      # global router instance
      rheia.router = @

      rheia.imagesService = new ImagesService()

      # Define some URL routes (order is significant: evaluated from last to first)
      @route '*route', '_onNotFound'
      @route 'login', '_onDisplayLogin'
      @route 'login?error=:err', '_onLoginError'
      @route 'login?token=:token', '_onLoggedIn'
      @route 'login?redirect=:redirect', 'logAndRedirect', (redirect) =>
        localStorage.setItem 'rheia.redirect', decodeURIComponent redirect
        @_onDisplayLogin()
      @route 'edition', 'edition', =>
        @_showPerspective 'editionPerspective', EditionPerspective
      @route 'authoring', 'authoring', =>
        @_showPerspective 'authoringPerspective', AuthoringPerspective
      @route 'admin', 'admin', =>
        @_showPerspective 'administrationPerspective', AdminPerspective
      @route 'moderation', 'moderation', =>
        @_showPerspective 'moderationPerspective', ModerationPerspective

      # general error handler
      @on 'serverError', (err, details) ->
        console.error "server error: #{if typeof err is 'object' then err.message else err}"
        console.dir details
      
      # route link special behaviour
      $('body').on 'click', 'a[data-route]', (event) =>
        event.preventDefault()
        route = $(event.target).closest('a').data 'route'
        @navigate route, trigger: true

      # run current route
      Backbone.history.start
        pushState: true
        root: conf.basePath

    # **private**
    # Show a perspective inside the wrapper. First check the connected status.
    #
    # @param name [String] Name of the perspective, used to store it inside the rheia global object
    # @param Perspective [Class] the Perspective class
    _showPerspective: (name, Perspective) =>
      return if perspectiveLoading
      perspectiveLoading = true
      # check if we are connected
      if rheia.sockets.game is null
        perspectiveLoading = false
        token = localStorage.getItem 'rheia.token'
        return @navigate 'login', trigger:true unless token?
        return @_onLoggedIn token

      # update last perspective visited
      localStorage.setItem 'rheia.lastPerspective', window.location.pathname.replace conf.basePath, ''

      rheia.layoutView.loading i18n.titles[name]
      # puts perspective content inside layout if it already exists
      if name of rheia
        rheia.layoutView.show rheia[name].$el
        return perspectiveLoading = false

      # or requires, instanciate and render the view
      rheia[name] = new Perspective()
      rheia.layoutView.show rheia[name].render().$el
      perspectiveLoading = false

    # **private**
    # Display the login view
    _onDisplayLogin: =>
      form = $('#loginStock').detach()
      $('body').empty().append new LoginView(form).render().$el

    # **private**
    # Invoked when coming-back from an authentication provider, with a valid token value.
    # Wired to server with socket.io
    #
    # @param token [String] valid autorization token
    _onLoggedIn: (token) =>
      redirect = localStorage.getItem 'rheia.redirect'
      if redirect?
        localStorage.removeItem 'rheia.redirect'
        return window.location.pathname = redirect
      # Connects token
      connect token, =>
        # removes previous error
        $('#loginError').dialog 'close'

        # do not recreates singletons in case of reconnection
        if $('body > .layout').length is 0
          # instanciates singletons.
          rheia.searchService = new SearchService()
          rheia.adminService = new AdminService()
          rheia.layoutView = new LayoutView()

          # display layout
          $('body').append rheia.layoutView.render().$el

        # allow other part to wire to updates
        $(window).trigger 'connected'

        # run current or last-saved perspective
        current = window.location.pathname.replace conf.basePath, ''
        current = localStorage.getItem 'rheia.lastPerspective' if current is 'login'
        current = 'edition' unless current?
        # reset Backbone.history internal state to allow re-running current route
        Backbone.history.fragment = null
        @navigate current, trigger:true
      , (err) =>
        # something goes wrong !
        @_onLoginError err.replace('handshake ', '').replace('error ', '')

    # **private**
    # Invoked when the login mecanism failed. Display details to user and go back to login
    # 
    # @param err [String] error details
    _onLoginError: (err) =>
      err = decodeURIComponent err
      msg = err
      for pattern, key of errorMapping when err.match pattern
        msg = i18n.errors[key]
        break

      utils.popup i18n.titles.loginError, msg, 'warning', [
        text: i18n.buttons.ok, 
        icon:'valid'
        click: => 
          @navigate 'login', trigger:true unless err is 'disconnected'
      ], 0, 'loginError'

    # **private**
    # Invoked when a route that doesn't exists has been run.
    # 
    # @param route [String] the unknown route
    _onNotFound: (route) =>
      console.error "Unknown route #{route}"
      @navigate 'login', trigger: true

  new Router()