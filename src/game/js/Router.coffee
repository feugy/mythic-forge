define [
  'lib/jquery' 
  'lib/underscore'
  'lib/backbone'
  'model/Item'
  'view/MapView'
  ], ($, _, Backbone, Item, MapView) ->

  Item.collection.on 'add', (added, items) ->
    console.log "new item #{added.get('_id')} #{added.get('name')}"

  class Router extends Backbone.Router

    routes:
      # Define some URL routes
      'home': 'displayMapView'

    views:
      map: new MapView()

    # Object constructor.
    #
    # For links that have a route specified (attribute data-route), prevent link default action and
    # and trigger route navigation.
    #
    # Starts history tracking in pushState mode
    constructor: ->
      super()
      Backbone.history.start pushState: true

      # route link special behaviour
      $('a[data-route]').on 'click', (e) =>
        e.preventDefault()
        route = $(e.target).data 'route'
        console.log "Run client route: #{route}"
        @navigate route, trigger: true

      # consult the map
      Item.collection.fetch {lowX:0, lowY:0, upX:10, upY:10}
      # display map first
      @navigate 'home', trigger: true

    displayMapView: =>
      $('.map').append @views.map.render().$el

  app = new Router()
