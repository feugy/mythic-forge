define [
  'lib/jquery' 
  'lib/underscore'
  'lib/backbone'
  'model/Map'
  'model/Item'
  'model/Field'
  'view/MapView'
  'service/RuleService'
  'service/ImagesLoader'
  ], ($, _, Backbone, Map, Item, Field, MapView, RuleService, ImagesLoader) ->

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

    displayMapView: =>
      $('.map').append @mapView.render().$el

  app = new Router()
  return app