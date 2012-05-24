define ['lib/jquery', 'lib/underscore', 'lib/backbone'], ($, _, Backbone)->
#define ['lib/jquery', 'lib/backbone'], ($, Backbone)->

  AppRouter = Backbone.Router.extend
    routes:
      # Define some URL routes
      'hello': 'sayHello'
        
    sayHello: =>
      $('body').append '<p>Hello</p>'

  $('a').on 'click', (e) =>
    e.preventDefault()

  app = new AppRouter()
  Backbone.history.start pushState: true