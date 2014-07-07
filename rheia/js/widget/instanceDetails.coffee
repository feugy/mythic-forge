###
  Copyright 2010~2014 Damien Feugas

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
  # Displays a contextual menu, but handlers are defined by instanceTree widget.
  class InstanceDetails extends Base

    # **private**
    # created tooltip
    _tooltip: null

    # **private**
    # simple timeout to delay tooltip opening
    _tooltipTimeout: null
      
    # **private**
    # contextual menu
    _menu: null

    # initialize widget
    constructor: (element, options) ->
      super element, options
      @_create()

    # destructor: free DOM nodes and handles
    dispose: =>
      @_tooltip?.$el.remove()
      @$el.find('*').off()
      super()

    # build rendering
    _create: =>
      instance = @options.value
      @$el.addClass 'instance-details'

      name = null
      if instance? and 'object' is utils.type instance
        # displays an image if a type is available
        if instance.type? 
          img = instance.type.descImage
          $('<span></span>').mapItem(
            model: instance
            noUpdate: @options.noUpdate
          ).appendTo @$el
        else
          @$el.addClass 'no-image'

        name = utils.instanceName instance

        # displays label with name
        @$el.append "<span>#{_.sprintf i18n.instanceDetails.name, name, instance.id}</span>"
      
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
          # hides tooltip if over menu
          return @_tooltip?.close() unless $(event.target).closest('.menu').length is 0
          # otherwise, opens it with a slight delay
          @_tooltipTimeout = setTimeout =>
            if @_tooltip
              return if @_tooltip.options.open
            else
              @_tooltip = $("<div class='tooltip'>#{@options.tooltipFct @options.value}</div>")
                .appendTo('body')
                .toggleable(
                  firstShowDelay: 1000
                ).data 'toggleable'
            # do not open tooltip on mouse position, to avoid intersepting clicks
            @_tooltip.open event.pageX+10, event.pageY+10
          , 500
        @$el.on 'mouseleave', => clearTimeout @_tooltipTimeout

      if @_menu?
        @$el.off 'contextmenu', @_onShowMenu 
        @_menu.remove()

      # adds a contextual menu that opens on right click
      @_menu = $("""<ul class="menu">
          <li class="open"><i class="x-small ui-icon open"></i>#{_.sprintf i18n.instanceDetails.open, name}</li>
          <li class="remove"><i class="x-small ui-icon remove"></i>#{_.sprintf i18n.instanceDetails.remove, name}</li>
        </ul>""").toggleable().appendTo(@$el).data 'toggleable'

      @$el.on 'contextmenu', @_onShowMenu

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

    # **private**
    # Contextual menu handler, to show existing menu
    #
    # @param event [Event] cancelled right click event
    _onShowMenu: (event) =>
      event?.preventDefault()
      event?.stopImmediatePropagation()
      # remove tooltip if visible or pending
      clearTimeout @_tooltipTimeout
      @_tooltip?.close()
      # opens menu
      @_menu.open event?.pageX, event?.pageY

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

    # Indicate whether or not this widget should update himself when the underluying model is updated
    noUpdate: false