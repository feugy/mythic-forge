###
  Copyright 2010~2014 Damien Feugas
  
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
  'i18n!nls/administration'
  'text!tpl/administrationPerspective.html'
  'view/admin/Deploy'
  'view/admin/Turns'
  'view/admin/Log'
  'view/admin/Time'
], ($, Backbone, i18n, i18nAdmin, template, DeployView, TurnsView, LogView, TimeView) ->

  i18n = $.extend true, i18n, i18nAdmin

  # The administration perspective do not handle tab views, and do not need to extend
  # TabView. It embeds the the deploy and turn views
  class Perspective extends Backbone.View
    
    # **private**
    # mustache template rendered
    _template: template

    # The view constructor.
    #
    # @param className [String] css ClassName, set by subclasses
    constructor: (className) ->
      super tagName: 'div', className:'admin perspective'

    # The `render()` method is invoked by backbone to display view content at screen.
    # Instanciate views and add them to rendering
    render: =>
      super()
      # creates the views
      @$('.right').append(new DeployView().$el)
        .append new LogView().$el
      @$('.left').append(new TimeView().$el)
        .append new TurnsView().$el

      # for chaining purposes
      @