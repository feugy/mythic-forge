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
  'underscore'
  'backbone'
  'moment'
  'utils/utilities'
  'i18n!nls/common'
  'i18n!nls/administration'
  'text!tpl/timeView.html'
], ($, _, Backbone, moment, utils, i18n, i18nAdmin, template) ->

  i18n = $.extend true, i18n, i18nAdmin

  # The time views displays current time and allow to stop and change it
  class Time extends Backbone.View
    
    # used by template
    i18n: i18n

    events: 
      'click .toggle-time': '_onToggle'

    # **private**
    # mustache template rendered
    _template: template

    # **private** 
    # time input
    _time: null

    # **private**
    # Paused status
    _paused: false

    # The view constructor.
    #
    # @param className [String] css ClassName, set by subclasses
    constructor: (className) ->
      super tagName: 'div', className:'time view'
      @_paused = conf.timer.paused
      utils.onRouterReady =>
        @bindTo app.sockets.updates, 'change', @_onTimeChanged

      @render()

    # rendering method
    render: =>
      super()
      @$('.toggle-time').button
        text: true
        icons: 
          primary: if @_paused then 'ui-icon-play small' else 'ui-icon-pause small'
        label: if @_paused then i18n.buttons.playTime else i18n.buttons.pauseTime
      
      @_time = @$('input.time').datetimepicker
        showSecond: true
        # unfortunately, moment and jquery datetimepiker do not share their formats...
        dateFormat: i18n.constants.dateFormat.toLowerCase()
        timeFormat: i18n.constants.timeFormat.toLowerCase()
        onSelect: @_onSetTime

      @_time.datetimepicker 'setDate', moment(conf.timer.value).toDate()
      @

    # **private**
    # Update the displayed time, unless it has focus
    #
    # @param event [String] update kind. Only `time` is supported
    # @param time [Number] Unix epoch of the new time
    _onTimeChanged: (event, time) =>
      return if event isnt 'time' or $('#ui-datepicker-div').is ':visible'
      # update displayed time
      @_time.datetimepicker 'setDate', moment(time).toDate()

    # **private**
    # Set to server the new time
    _onSetTime: =>
      # unfortunately, moment and jquery datetimepiker do not share their formats...
      newTime = moment(@_time.val(), "#{i18n.constants.dateFormat.replace 'YY', 'YYYY'} #{i18n.constants.timeFormat}").valueOf()
      # send to server
      app.sockets.admin.emit 'setTime', utils.rid(), newTime

    # **private**
    # Toggle the paused state.
    #
    # @param event [Event] optionnal cancelled click event
    _onToggle: (event) =>
      event?.preventDefault()
      # invert paused state and send to server
      @_paused = !@_paused
      @$('.toggle-time').button 'option',
        icons: 
          primary: if @_paused then 'ui-icon-play small' else 'ui-icon-pause small'
        label: if @_paused then i18n.buttons.playTime else i18n.buttons.pauseTime
      app.sockets.admin.emit 'pauseTime', utils.rid(), @_paused