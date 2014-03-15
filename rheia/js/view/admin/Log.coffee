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
  'underscore'
  'backbone'
  'moment'
  'utils/utilities'
  'i18n!nls/common'
  'i18n!nls/administration'
  'text!tpl/logView.html'
], ($, _, Backbone, moment, utils, i18n, i18nAdmin, template) ->

  i18n = $.extend true, i18n, i18nAdmin

  limit = 2000

  # The log views displays colorized logs
  class Log extends Backbone.View
    
    # used by template
    i18n: i18n

    # **private**
    # mustache template rendered
    _template: template

    # **private** 
    # logs container
    _logs: null

    # **private**
    # number of log lines, to avoid having too much logs
    _count: 0

    # The view constructor.
    #
    # @param className [String] css ClassName, set by subclasses
    constructor: (className) ->
      super tagName: 'div', className:'logs view'
      @_count = 0;
      utils.onRouterReady =>
        @bindTo app.sockets.admin, 'log', @_onLog

      @render()

    # rendering method
    render: =>
      super()
      @_logs = @$('.logs-panel')
      @

    # **private**
    # Render a line of logs inside content
    _onLog: (details) =>
      return unless @_logs?

      # compute scroll height
      height = @_logs[0].scrollHeight - @_logs.outerHeight()

      # avoid to much logs
      if @_count > limit
        @_logs.children(':last').remove()
      else
        @_count++

      # date name level parameter : message
      vals = (if _.isObject arg then JSON.stringify arg else arg?.toString() for arg in details.args)

      # put at first line and the compute height
      lineHeight = $("""<div class="log #{details.level}">
        <span class="date">#{moment().format i18n.logs.dateFormat}</span>
        <span class="name">#{_.pad details.name, i18n.logs.nameMaxLength}</span>
        <span class="level">#{_.pad details.level, i18n.logs.levelMaxLength}</span>
        <span class="message">#{vals.join ' '}</span>
        </div>""").prependTo(@_logs).outerHeight()

      pos = @_logs.scrollTop()
      # scroll to top, only if the scroller is already at top
      @_logs.scrollTop 0 if pos < height