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
  'view/edition/Explorer'
], (Backbone, $, Explorer) ->

  # The edition perspective manages types, rules and maps
  #
  class EditionPerspective extends Backbone.View

    # The view constructor.
    #
    # @param router [Router] the event bus
    constructor: (@router) ->
      super {tagName: 'div', className:'edition perspective'}

      # construct explorer
      @explorer = new Explorer @router

    # The `render()` method is invoked by backbone to display view content at screen.
    # Draws the login form.
    render: =>
      @$el.append '<div class="row"><div class="left cell"></div><div class="right cell"></div></div>'
      @$el.find('.cell.left').append @explorer.render().$el
      # for chaining purposes
      return @

  return EditionPerspective