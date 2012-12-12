###
  Copyright 2010,2011,2012 Damien Feugas

    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http:#www.gnu.org/licenses/>.
###
'use strict'

define [
  'jquery'
  'underscore'
  'utils/utilities'
  'i18n!nls/common'
  'i18n!nls/widget'
  'widget/base'
  'widget/loadableImage'
  'widget/toggleable'
], ($, _, utils, i18n, i18nWidget, Base) ->

  i18n = $.extend true, i18n, i18nWidget

  # This widget displays a list of linked instances, using instanceDetails for rendergin.
  # The size list could be limited to 1, and any modification will remplace the previous value.
  class InstanceDetails extends Base

    # **private**
    # created tooltip
    _tooltip: null

    # **private**
    # simple timeout to delay tooltip opening
    _tooltipTimeout: null
      
    # initialize widget
    constructor: (element, options) ->
      super element, options
      @_create()

    # destructor: free DOM nodes and handles
    dispose: =>
      @_tooltip?.$el.remove()
      @$el.find('*').unbind()
      super()

    # build rendering
    _create: =>
      instance = @options.value

      @$el.addClass 'instance-details'

      # destroy if needed
      @bindTo instance, 'destroy', => @$el.remove() if instance?

      if instance? and 'object' is utils.type instance
        # displays an image if a type is available
        if instance.type? 
          img = instance.type.descImage
          $('<span></span>').mapItem(
            model: instance
          ).appendTo @$el
        else
          @$el.addClass 'no-image'

        # displays label with name
        @$el.append "<span>#{_.sprintf i18n.instanceDetails.name, utils.instanceName(instance), instance.id}</span>"
      
      if @options.dndType?
        @$el.draggable
          scope: @options.dndType
          appendTo: 'body'
          distance: 15
          cursorAt: top:-5, left:-5
          helper: => utils.dragHelper @options.value

      # adds a tooltip
      if 'function' is utils.type @options.tooltipFct
        @$el.on 'mouseenter', (event) =>
          clearTimeout @_tooltipTimeout
          @_tooltipTimeout = setTimeout =>
            if @_tooltip
              return if @_tooltip.options.open
            else
              @_tooltip = $("<div class='tooltip'>#{@options.tooltipFct @options.value}</div>")
                .appendTo('body')
                .toggleable(
                  firstShowDelay: 1000
                ).data 'toggleable'
            @_tooltip.open event.pageX, event.pageY
          , 500
        @$el.on 'mouseleave', => clearTimeout @_tooltipTimeout

    # Method invoked when the widget options are set. Update rendering if value change.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option
    setOption: (key, value) =>
      return unless key in ['value']
      # updates inner option
      @options[key] = value
      # refresh rendering.
      @$el.find('*').unbind()
      @$el.empty()
      @_create()

  # widget declaration
  InstanceDetails._declareWidget 'instanceDetails', 

    # Currently displayed object
    value: null
    
    # Scope used to drag objects from widget. Null to disable
    dndType: null
    
    # Tooltip generator. 
    # This function takes displayed object as parameter, and must return a string, used as tooltip.
    # If null is returned, no tooltip displayed
    tooltipFct: null
    
    # Tooltip animations length
    tooltipFade: 250