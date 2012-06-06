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
  'view/HomeView'
  'service/RuleService'
  'service/PlayerService'
  'service/ImagesLoader'
  ], ($, Backbone, Map, Item, Field, MapView, HomeView, RuleService, PlayerService, ImagesLoader) ->

  class Router extends Backbone.Router

    routes:
      # Define some URL routes
      'map': 'map'
      'home': 'home'

    # Equalivalent to webkit's `window.location.origin`
    origin: (''+window.location).replace(new RegExp(window.location.pathname+'$'), '')

    # The mapView singleton  
    mapView: null

    # The ruleService singleton
    ruleService: null

    # The player service singleton
    playerService: null

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
      @playerService = new PlayerService this
      @imagesLoader = new ImagesLoader this
      
      # bind the map and the content of the items and fields collections
      @homeView = new HomeView this

      Backbone.history.start pushState: true

      # route link special behaviour
      $('a[data-route]').on 'click', (e) =>
        e.preventDefault()
        route = $(e.target).data 'route'
        console.log "Run client route: #{route}"
        @navigate route, trigger: true
      
      # display map first
      @navigate 'home', trigger: true

      # global key handler
      $(window).on 'keyup', (event) =>
        # broadcast on the event bus.
        @trigger 'key', {code: event.which, shift: event.shiftKey, ctrl: event.ctrlKey, meta: event.metaKey} 

    # Displays map view
    map: =>
      # go back to home if no player connected
      return @navigate 'home', true if @playerService.connected is null
      # bind the map and the content of the items and fields collections
      @mapView = new MapView @playerService.connected.get('character'), 0, 0, this, [Item.collection, Field.collection], @imagesLoader
      # displays it    
      $('body').empty().append @mapView.render().$el

    # Displays home view
    home: =>
      $('body').empty().append @homeView.render().$el

  app = new Router()
  return app