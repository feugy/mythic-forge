define [
  'lib/jquery' 
  'lib/underscore'
  'lib/backbone'
  'model/Item'
  'view/MapView'
  'service/RuleService'
  'service/ImagesLoader'
  ], ($, _, Backbone, Item, MapView, RuleService, ImagesLoader) ->

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
      @mapView = new MapView {
        # bind the map and the content of the item collection
        collection: Item.collection
        originX: 0
        originY: 0
        router: this
        imagesLoader: @imagesLoader
      }

      Backbone.history.start pushState: true

      # route link special behaviour
      $('a[data-route]').on 'click', (e) =>
        e.preventDefault()
        route = $(e.target).data 'route'
        console.log "Run client route: #{route}"
        @navigate route, trigger: true

      # consult the map TODO: do not hardcode map
      Item.collection.fetch
        map: '4fc334d5f184130eda1b61fc'
        lowX: @mapView.originX
        lowY: @mapView.originY
        upX: @mapView.originX+10
        upY: @mapView.originY+10
      
      # display map first
      @navigate 'map', trigger: true

    displayMapView: =>
      $('.map').append @mapView.render().$el

  app = new Router()
  return app