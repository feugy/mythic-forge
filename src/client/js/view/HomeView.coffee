define [
  'backbone'
  'jquery'
], (Backbone, $) ->

  # The home view displays a login form.
  #
  class HomeView extends Backbone.View

    # events mapping
    events:
      'submit #loginForm': '_onLogin'

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param originY [Number] displayed game coordinate ordinate
    constructor: (@router) ->
      super {tagName: 'div'}

    # The `render()` method is invoked by backbone to display view content at screen.
    # Draws the login form.
    render: =>
      @$el.empty().append '<form id="loginForm"><label>Login: </label><input type="text" value="login"/></form>'

    _doLogin: (event) =>
      # discard form submission
      return false

  return HomeView