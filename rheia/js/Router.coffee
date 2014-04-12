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
    'backbone': 'lib/backbone-1.1.0-min'
    'backbone-queryparams': 'lib/backbone-queryparams-min',
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
    'socket.io': 'lib/socket.io-1.0.0-pre'
    'text': 'lib/text-2.0.0-min'
    'timepicker': 'lib/jquery-timepicker-addon-1.0.1-min'
    'tpl': '../template'
    'transit': 'lib/jquery-transit-0.9.9-min'
    'underscore': 'lib/underscore-1.4.3-min'
    'underscore.string': 'lib/underscore.string-2.3.0-min'
    'utf8': 'lib/utf8'
    'hyperion': './'
    
  shim:
    'ace/ace':
      exports: 'ace'
    'async': 
      exports: 'async'
    'backbone': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'backbone-queryparams': 
      deps: ['backbone']
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

# initialize application global namespace
window.app = {}

# Mapping between socket.io error reasons and i18n error messages
errorMapping = 
  'unauthorized': 'unauthorized'
  'invalidToken': 'invalidToken'
  'expiredToken': 'expiredToken'
  'disconnected': 'disconnected'
  'kicked': 'kicked'
  'wrongCredentials': 'wrongCredentials'
  'missingCredentials': 'wrongCredentials'
  'deploymentInProgress': 'deploymentInProgress'
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
  'model/Item'
  'view/admin/Perspective'
  'view/edition/Perspective'
  'view/authoring/Perspective'
  'view/moderation/Perspective'
  'view/Layout'
  # unwired dependencies
  'backbone-queryparams'
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

], (_, $, io, async, Backbone, LoginView, i18n, utils, ImagesService, SearchService, AdminService, Item,
  AdminPerspective, EditionPerspective, AuthoringPerspective, ModerationPerspective, LayoutView) ->

  version = parseInt $.browser.version
  return $('.disclaimer').show() unless ($.browser.mozilla and version >= 14) or 
    ($.browser.webkit and version >= 530) or
    ($.browser.chrome and version >= 20)

  # simple flag to avoid loading multiple perspective at the same time
  perspectiveLoading = false
  isLoggingOut = false
  connecting = false

  $(window).on 'beforeunload', () ->
    isLoggingOut = true
    undefined

  # different namespaces that ca be used to communicate qith server
  app.sockets =
    game: null
    admin: null
    updates: null

  # the connect function will try to connect with server. 
  # 
  # @param token [String] the autorization token, obtained during authentication
  # @param callback [Function] invoked when all namespaces have been connected, with arguments
  # @option callback err [String] the error detailed case, or null if no error occured
  connect = (token, callback) ->
    isLoggingOut = false
    connecting = true

    # wire logout facilities
    app.router.on 'logout', -> 
      localStorage.removeItem 'app.token'
      isLoggingOut = true
      socket.emit 'logout'
      app.router.navigate 'login', trigger: true

    socket = io.connect conf.apiBaseUrl, query:"token=#{token}", transports: ['websocket', 'polling', 'flashsocket']

    # only report error during connection phase
    socket.on 'error', (err) ->
      if connecting
        connecting = false 
        callback err 

    socket.on 'disconnect', (reason) ->
      return if isLoggingOut
      console.log "disconnected for #{reason}"
      # TODO plus moyen de savoir pourquoi on a été décconnecté
      if reason is 'booted'
        document.cookie = "key=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/"
      callback 'disconnected'

    socket.io.on 'reconnect_attempt', ->
      # don't forget to set connecting flag again for error handling
      connecting = true

    socket.on 'connect', (err) ->
      return if err?
      # close previous error (for example connection lost message)
      $('#loginError').dialog 'close'

      connecting = false 
      # On connection, retrieve current connected player immediately
      socket.emit 'getConnected', (err, player) ->
        # stores the token to allow re-connection
        app.player = player
        localStorage.setItem 'app.token', player.token
        # set cookie for dev access if admin
        if player.key
          document.cookie = "key=#{player.key}; max-age=#{1000*60*60*24}; path=/"
        # update socket.io query to allow reconnection with new token value
        socket.io.opts.query = "token=#{player.token}"

      # connect on existing namespaces
      names = Object.keys app.sockets
      async.forEach names, (name, next) ->
        return next null if app.sockets[name]?
        app.sockets[name] = socket.io.socket "/#{name}"
        app.sockets[name].on 'connect', next
        app.sockets[name].on 'connect_error', next
      , callback

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
      app.router = @

      app.imagesService = new ImagesService()

      # Define some URL routes (order is significant: evaluated from last to first)
      @route '*route', '_onNotFound'
      @route 'login', '_onDisplayLogin'
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
      if app.sockets.game is null
        perspectiveLoading = false
        token = localStorage.getItem 'app.token'
        return @navigate 'login', trigger:true unless token?
        return @_onLoggedIn token

      # update last perspective visited
      localStorage.setItem 'app.lastPerspective', window.location.pathname.replace conf.basePath, ''

      app.layoutView.loading i18n.titles[name]
      # puts perspective content inside layout if it already exists
      if name of app
        app.layoutView.show app[name].$el
        return perspectiveLoading = false

      # or requires, instanciate and render the view
      app[name] = new Perspective()
      app.layoutView.show app[name].render().$el
      perspectiveLoading = false

    # **private**
    # Display the login view
    _onDisplayLogin: (params)=>
      if params?.error?
        @_onLoginError params.error
      else if params?.token?
        @_onLoggedIn params.token
      else 
        if params?.redirect?
          localStorage.setItem 'app.redirect', decodeURIComponent params.redirect
        form = $('#loginStock').detach()
        $('body').empty().append new LoginView(form).render().$el

    # **private**
    # Invoked when coming-back from an authentication provider, with a valid token value.
    # Wired to server with socket.io
    #
    # @param token [String] valid autorization token
    _onLoggedIn: (token) =>
      redirect = localStorage.getItem 'app.redirect'
      if redirect?
        localStorage.removeItem 'app.redirect'
        return window.location.pathname = redirect

      # Connects token
      connect token, (err) =>
        # removes previous error
        $('#loginError').dialog 'close'
        # something goes wrong !
        return @_onLoginError err.toString().replace('error ', '') if err?

        # do not recreates singletons in case of reconnection
        if $('body > .layout').length is 0
          # instanciates singletons.
          app.searchService = new SearchService()
          app.adminService = new AdminService()
          app.layoutView = new LayoutView()

          # display layout
          $('body').append app.layoutView.render().$el

        # allow other part to wire to updates
        $(window).trigger 'connected'

        # run current or last-saved perspective
        current = window.location.pathname.replace conf.basePath, ''
        current = localStorage.getItem 'app.lastPerspective' if current is 'login'
        current = 'edition' unless current?
        # reset Backbone.history internal state to allow re-running current route
        Backbone.history.fragment = null
        @navigate current, trigger:true

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