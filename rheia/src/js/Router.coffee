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
###
'use strict'

requirejs.config 
  paths:
    'backbone': 'lib/backbone-0.9.2-min'
    'underscore': 'lib/underscore-1.3.3-min'
    'jquery': 'lib/jquery-1.7.2-min'
    'socket.io': 'lib/socket.io-0.9.6-min'
    'async': 'lib/async-0.1.22-min'
    'i18n': 'lib/i18n'
    
  shim:
    'backbone': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'underscore': 
      exports: '_'
    'jquery': 
      exports: '$'
    'socket.io': 
      exports: 'io'
    'async': 
      exports: 'async'

define [
  'jquery' 
  'backbone'
  'service/ImagesLoader'
  'view/edition/Perspective'
  ], ($, Backbone, ImagesLoader, EditionPerspectiveView) ->

  class Router extends Backbone.Router

    routes:
      # Define some URL routes
      'home': 'home'

    # The images loader singleton
    imagesLoader: null

    # Object constructor.
    #
    # For links that have a route specified (attribute data-route), prevent link default action and
    # and trigger route navigation.
    #
    # Starts history tracking in pushState mode
    constructor: ->
      super()
      # instanciates singletons.
      @imagesLoader = new ImagesLoader this
      
      @editionPerspective = new EditionPerspectiveView this

      Backbone.history.start {pushState: true, root: conf.basePath}

      # route link special behaviour
      $('a[data-route]').on 'click', (e) =>
        e.preventDefault()
        route = $(e.target).data 'route'
        console.log "Run client route: #{route}"
        @navigate route, trigger: true
      
      # display map first
      @navigate 'home', trigger: true

    # Displays home view
    home: =>
      $('body').empty().append @editionPerspective.render().$el

  app = new Router()
  return app