define [
  'lib/jquery' 
  'lib/underscore'
  'lib/backbone'
  'model/Item'
  ], ($, _, Backbone, Item) ->

  Item.collection.on 'add', (added, items) ->
    console.log "new item #{added.get('_id')} #{added.get('name')}"

  Router = Backbone.Router.extend

    routes:
      # Define some URL routes
      'hello': 'sayHello'

    # Object constructor, called by Backbone.
    #
    # for links that have a route specified (attribute data-route), prevent link default action and
    # and trigger route navigation.
    initialize: ->
      Backbone.history.start pushState: true

      $('a[data-route]').on 'click', (e) =>
        e.preventDefault()
        route = $(e.target).data 'route'
        console.log "Run client route: #{route}"
        @navigate route, trigger: true

      # consult the map
      Item.collection.fetch {lowX:0, lowY:0, upX:10, upY:10}

    sayHello: =>
      $('body').append '<p>Hello</p>'

  app = new Router()
