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
    'md5': 'lib/md5-2.2-min'
    'html5slider': 'lib/html5slider-min'
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
    'utils/Milk': 
      exports: 'Milk'

# initialize rheia global namespace
window.rheia = {}

define [
  'underscore'
  'underscore.string'
  'jquery' 
  'backbone'
  'view/edition/Perspective'
  'service/ImagesService'
  # unwired dependencies
  'jquery-ui' 
  'numeric' 
  'transit'
  'timepicker'
  'hotkeys'
  'mousewheel'
  'md5'
  'html5slider'
  ], (_, _string, $, Backbone, EditionPerspectiveView, ImagesService) ->

  # mix in non-conflict functions to Underscore namespace if you want
  _.mixin(_string.exports())
  _.mixin(
    includeStr: _string.include
    reverseStr: _string.reverse
  )

  # enhance Backbone views with close() mechanism
  _.extend Backbone.View.prototype, 

    # **private**
    # Array of bounds between targets and the view, that are unbound by `destroy`
    _bounds: []

    # overload the initialize method to bind `destroy()`
    initialize: () ->
      # initialize to avoid static behaviour
      @_bounds = []
      # bind to remove element to call the close method.
      @$el.bind('remove', ()=> @dispose())

    # Allows to bound a callback of this view to the specified emitter
    # bounds are keept and automatically unbound by the `destroy` method.
    #
    # @param emitter [Backbone.Event] the emitter on which callback is bound
    # @param events [String] events on which the callback is bound
    # @parma callback [Function] the bound callback
    bindTo: (emitter, events, callback) ->
      emitter.on(events, callback)
      @_bounds.push([emitter, events, callback])

    # The destroy method correctly free DOM  and event handlers
    # It must be overloaded by subclasses to unsubsribe events.
    dispose: () ->
      # automatically remove bound callback
      spec[0].off(spec[1], spec[2]) for spec in @_bounds
      # unbind DOM callback
      @$el.unbind()
      # remove rendering
      @remove()
      @trigger('dispose', @)

  class Router extends Backbone.Router

    routes:
      # Define some URL routes
      'home': 'home'

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
      rheia.editionPerspective = new EditionPerspectiveView()

      Backbone.history.start({pushState: true, root: conf.basePath})

      # general error handler
      @on('serverError', (err, details) ->
        console.error("server error: #{if typeof err is 'object' then err.message else err}")
        console.dir(details)
      )

      # route link special behaviour
      ###$('a[data-route]').on 'click', (e) =>
        e.preventDefault()
        route = $(e.target).data 'route'
        console.log "Run client route: #{route}"
        @navigate route, trigger: true###
      
      # display map first
      @navigate('home', trigger: true)

    # Displays home view
    home: =>
      $('body').empty().append(rheia.editionPerspective.render().$el)

  app = new Router()
  return app