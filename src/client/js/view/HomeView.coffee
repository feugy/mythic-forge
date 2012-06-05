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

    # last login.
    _login: null

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param originY [Number] displayed game coordinate ordinate
    constructor: (@router) ->
      super {tagName: 'div'}
      @router.on 'authenticated', @_onAuthenticate
      @router.on 'registered', @_onAuthenticate

    # The `render()` method is invoked by backbone to display view content at screen.
    # Draws the login form.
    render: =>
      @$el.append '<form id="loginForm"><label>Login: </label><input type="text" name="login" placeholder="Your login"/><input type="submit" value="connect"/></form>'
      # for chaining purposes
      return @

    # Handler that delegate authentication to the PlayerService.
    #
    # @param event [Event] the form subimission event.
    _onLogin: (event) =>
      @_login = @$el.find('#loginForm [name=login]').val()
      @router.trigger 'authenticate', @_login
      # discard form submission
      return false

    # Authentication end handler.
    # If authentication failed, try to create a new account.
    # If it succeeded, displays the map.
    #
    # @param err [String] an error string. Null if no error occured
    # @param account [Player] the authenticated account 
    _onAuthenticate: (err, account) =>
      if err is 'unknown account'
        # try to create new one.
        return @router.trigger 'register', @_login
      else if err?
        return alert "Authentication failure: #{err}"
      # all is fine: display map.
      @router.navigate 'map', trigger: true

  return HomeView