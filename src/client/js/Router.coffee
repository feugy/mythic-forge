requirejs.config 
  map:
   '*': 
    'backbone': 'lib/backbone-0.9.2-min'
    'underscore': 'lib/underscore-1.3.3-min'
    'jquery': 'lib/jquery-1.7.2-min'
    'socket.io': 'lib/socket.io-0.9.6-min'
    
  shim:
    'lib/backbone-0.9.2-min': 
      deps: ['underscore', 'jquery']
      exports: 'Backbone'
    'lib/underscore-1.3.3-min': 
      exports: '_'
    'lib/jquery-1.7.2-min': 
      exports: '$'
    'lib/socket.io-0.9.6-min': 
      exports: 'io'

define [
  'jquery' 
  'backbone'
  'model/Map'
  'model/Item'
  'model/Field'
  'view/MapView'
  'service/RuleService'
  'service/ImagesLoader'
  ], ($, Backbone, Map, Item, Field, MapView, RuleService, ImagesLoader) ->

  class Router extends Backbone.Router

    routes:
      # Define some URL routes
      'map': 'displayMapView'

    # Equalivalent to webkit's `window.location.origin`
    origin: (''+window.location).replace window.location.pathname, ''

    # The mapView singleton  
    mapView: null

    # The ruleService singleton
    ruleService: null

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
      @ruleService = new RuleService this
      @imagesLoader = new ImagesLoader this
      
      # consult the map TODO do not hardcode
      map = new Map {_id: '4fc334d5f184130eda1b61fc', name: 'world' }

      # bind the map and the content of the items and fields collections
      @mapView = new MapView map, 0, 0, this, [Item.collection, Field.collection], @imagesLoader

      Backbone.history.start pushState: true

      # route link special behaviour
      $('a[data-route]').on 'click', (e) =>
        e.preventDefault()
        route = $(e.target).data 'route'
        console.log "Run client route: #{route}"
        @navigate route, trigger: true
      
      # display map first
      @navigate 'map', trigger: true

      # global key handler
      $(window).on 'keyup', (event) =>
        # broadcast on the event bus.
        @trigger 'key', {code: event.which, shift: event.shiftKey, ctrl: event.ctrlKey, meta: event.metaKey} 

    displayMapView: =>
      $('body').append @mapView.render().$el

  app = new Router()
  return app