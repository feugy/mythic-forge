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
  'i18n!nls/common'
  'text!tpl/layout.html'
], ($, Backbone, i18n, template) ->

  # The edition perspective manages types, rules and maps
  class Layout extends Backbone.View

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # the perspective container
    _container: null

    # The view constructor.
    constructor: () ->
      super({tagName: 'div', className:'layout'})
      Backbone.history.on('route', @_onRoute)

    # the render method, which use the specified template
    render:() =>
      super()
      @_container = @$el.find('.container')
      @$el.find('header a').each( () -> 
        $(this).button(
          text: false
          icons:
            primary: "ui-icon #{$(this).attr('class')}"
        )
      )
      # for chaining purposes
      return @

    # Empties layout's content a display loading animation
    #
    # @param title [String] the new title used for the layout
    loading: (title) =>
      @_container.empty()
      @$el.find('.loader').show()
      @$el.find('header h1').text(title)

    # Hides the loader and put content inside the container.
    #
    # @param content [jQuery] the content put inside layout
    show: (content) =>
      @_container.empty().append(content)
      @$el.find('.loader').hide()

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: () =>
      {i18n: i18n}

    # **private**
    # Route handler: activate the corresponding button
    #
    # @param history [Backbone.History] the history manager
    # @param handler [String] the ran handler
    _onRoute: (history, handler) =>
      for route, callback of history.routes when callback is handler
        @$el.find('header a').removeClass('active').filter("[data-route='/#{route}']").addClass('active')
        break