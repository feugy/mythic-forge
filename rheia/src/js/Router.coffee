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
    'backbone': 'lib/backbone-0.9.2'
    'underscore': 'lib/underscore-1.3.3-min'
    'underscore.string': 'lib/unserscore.string-2.2.0rc-min'
    'jquery': 'lib/jquery-1.7.2-min'
    'jquery-ui': 'lib/jquery-ui-1.8.21-min'
    'transit': 'lib/jquery-transit-0.1.3-min'
    'hotkeys': 'lib/jquery-hotkeys-min'
    'numeric': 'lib/jquery-ui-numeric-1.2-min'
    'timepicker': 'lib/jquery-timepicker-addon-1.0.1-min'
    'mousewheel': 'lib/jquery-mousewheel-3.0.6-min'
    'socket.io': 'lib/socket.io-0.9.6-min'
    'async': 'lib/async-0.1.22-min'
    'coffeescript': 'lib/coffee-script-1.3.3-min'
    'queryparser': 'lib/queryparser-1.0.0-min'
    'md5': 'lib/md5-2.2-min'
    'html5slider': 'lib/html5slider-min'
    'hogan': 'lib/hogan-2.0.0-min'
    'ace': 'lib/ace'
    'i18n': 'lib/i18n'
    'text': 'lib/text'
    'nls': '../nls'
    'tpl': '../templates'
    
  shim:
    'backbone': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'underscore': 
      exports: '_'
    'numeric':
      deps: ['jquery-ui']
    'timepicker':
      deps: ['jquery-ui']
    'mousewheel':
      deps: ['jquery']
    'jquery-ui':
      deps: ['jquery']
    'transit':
      deps: ['jquery']
    'hotkeys':
      deps: ['jquery']
    'jquery': 
      exports: '$'
    'socket.io': 
      exports: 'io'
    'async': 
      exports: 'async'
    'hogan': 
      exports: 'Hogan'
    'queryparser':
      exports: 'QueryParser'

# initialize rheia global namespace
window.rheia = {}

define [
  'underscore'
  'jquery' 
  'backbone'
  'view/Layout'
  'service/ImagesService'
  'service/SearchService'
  'i18n!nls/common'
  # unwired dependencies
  'utils/extensions'
  'jquery-ui' 
  'numeric' 
  'transit'
  'timepicker'
  'hotkeys'
  'mousewheel'
  'md5'
  'html5slider'
  ], (_, $, Backbone, LayoutView, ImagesService, SearchService, i18n) ->

  class Router extends Backbone.Router

    routes:
      # Define some URL routes
      'edition': '_onEdition'

    # Object constructor.
    #
    # For links that have a route specified (attribute data-route), prevent link default action and
    # and trigger route navigation.
    #
    # Starts history tracking in pushState mode
    constructor: () ->
      super()
      # global router instance
      rheia.router = @

      # instanciates singletons.
      rheia.imagesService = new ImagesService()
      rheia.searchService = new SearchService()
      rheia.layoutView = new LayoutView()

      Backbone.history.start({pushState: true, root: conf.basePath})

      # general error handler
      @on('serverError', (err, details) ->
        console.error("server error: #{if typeof err is 'object' then err.message else err}")
        console.dir(details)
      )

      # route link special behaviour
      $('body').on('click', 'a[data-route]', (event) =>
        event.preventDefault()
        route = $(event.target).data('route')
        @navigate(route, trigger: true)
      )

      # display layout
      $('body').empty().append(rheia.layoutView.render().$el)

      # TODO 
      @navigate('edition', trigger: true)

    # **private**
    # Show a perspective inside the wrapper
    _showPerspective: (name, path) =>
      rheia.layoutView.loading(i18n.titles[name])
      # puts perspective content inside layout if it already exists
      return rheia.layoutView.show(rheia[name].$el) if name of rheia

      # or requires, instanciate and render the view
      require([path], (Perspective) ->
        rheia[name] = new Perspective()
        rheia.layoutView.show(rheia[name].render().$el)
      ) 

    # **private**
    # Displays the edition perspective
    _onEdition: =>
      @_showPerspective('editionPerspective', 'view/edition/Perspective')

  app = new Router()
  return app