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
      'click .bot-mode': '_onBotMode'

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
      @$el.append '<a href="#" class="bot-mode">Enable bot-mode</a>'
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

    # Bot mode registers a random account and start moving randomly.
    _onBotMode: (event) =>
      @_login = "bot-#{Math.floor Math.random()*10001}"
      @router.trigger 'register', @_login
      false

  return HomeView