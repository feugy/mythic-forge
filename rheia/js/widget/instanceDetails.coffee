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
  'widget/baseWidget'
  'widget/loadableImage'
  'widget/toggleable'
], ($, _, utils, i18n, i18nWidget) ->

  i18n = $.extend true, i18n, i18nWidget

  # This widget displays a list of linked instances, using instanceDetails for rendergin.
  # The size list could be limited to 1, and any modification will remplace the previous value.
  $.widget 'rheia.instanceDetails', $.rheia.baseWidget,

    options:
      
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

    # **private**
    # created tooltip
    _tooltip: null

    # **private**
    # simple timeout to delay tooltip opening
    _tooltipTimeout: null
      
    # destructor: free DOM nodes and handles
    destroy: ->
      @_tooltip?.element.remove()
      @element.find('*').unbind()
      $.rheia.baseWidget::destroy.apply @, arguments

    # build rendering
    _create: ->
      $.rheia.baseWidget::_create.apply @, arguments
      instance = @options.value

      @element.addClass 'instance-details'

      if instance? and 'object' is utils.type instance
        # displays an image if a type is available
        if instance.get('type')? 
          # always use type image
          img = instance.get('type').get 'descImage'

          $('<div></div>').loadableImage(source: img, noButtons:true).appendTo @element if img?
        else
          @element.addClass 'no-image'

        # displays label with name
        @element.append "<span>#{_.sprintf i18n.instanceDetails.name, utils.instanceName(instance), instance.id}</span>"
      
      if @options.dndType?
        @element.draggable
          scope: @options.dndType
          appendTo: 'body'
          distance: 15
          cursorAt: top:-5, left:-5
          helper: => utils.dragHelper @options.value

      # adds a tooltip
      if 'function' is utils.type @options.tooltipFct
        @element.on 'mouseenter', (event) =>
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
          , 750
        @element.on 'mouseleave', => clearTimeout @_tooltipTimeout

    # **private**
    # Method invoked when the widget options are set. Update rendering if value change.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option
    _setOption: (key, value) ->
      return $.rheia.baseWidget::_setOption.apply @, arguments unless key in ['value']
      # updates inner option
      @options[key] = value
      # refresh rendering.
      @element.find('*').unbind()
      @element.empty()
      @_create()