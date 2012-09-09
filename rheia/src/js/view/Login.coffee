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
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

define [
  'jquery'
  'backbone'
  'text!tpl/login.html'
  'i18n!nls/common'
], ($, Backbone, template, i18n) ->

  # Displays and handle user login.
  class LoginView extends Backbone.View

    # **private**
    # mustache template rendered
    _template: template

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id, className) ->
      super tagName: 'div', className:'login-view'

    # the render method, which use the specified template
    render: =>
      super()
      # wire connection buttons and form
      @$el.find('.google').attr 'href', "#{conf.apiBaseUrl}/auth/google"
      @$el.find('.twitter').attr 'href', "#{conf.apiBaseUrl}/auth/twitter"
      @$el.find('form').attr 'action', "#{conf.apiBaseUrl}/auth/login"
      @$el.find('.login').button(
        text: true
        label: i18n.buttons.login
        icons:
          primary: 'ui-icon small login'
      ).click (event) => 
        event?.preventDefault()
        @$el.find('form').submit()
      
      # for chaining purposes
      @

    # **protected**
    # Provide template data for rendering
    #
    # @return an object used as template data 
    _getRenderData: -> 
      i18n: i18n
