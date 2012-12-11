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
  'widget/instanceDetails'
], ($, _, utils, i18n, i18nWidget, Base) ->

  i18n = $.extend true, i18n, i18nWidget

  # This widget displays a list of linked instances, using instanceDetails for rendergin.
  # The size list could be limited to 1, and any modification will remplace the previous value.
  # Supports drag'n drop operations for adding.replacing values.
  #
  # Triggers event `change` when an item is added or replace by drag'n drop, or removed by unbinding.
  # Triggers event `click` when an item is clicked.
  class InstanceList extends Base

    # build rendering
    constructor: (element, options) ->
      super element, options

      @$el.addClass 'instance-list'

      # add droppable capabilities
      if @options.dndType
        @$el.droppable
          scope: this.options.dndType
          tolerance: 'pointer'
          hoverClass: 'drop-hover'
          activeClass: 'drop-possible'
          accept: @_onAccept
          drop: @_onDrop

      # click handler
      @$el.on 'click', @_onClick
      
      # fills list
      @_create()

    # destructor: free DOM nodes and handles
    dispose: =>
      @$el.find('.unbind').off()
      super()

    # Method invoked when the widget options are set. Update rendering if value change.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option
    setOption: (key, value) =>
      return unless key in ['value', 'withUnbind']
      # updates inner option
      @options[key] = value
      return if @_inhibit
      # refresh rendering.
      @_create()

    # **private**
    # Effectively fills the linked object list
    _create: =>
      @$el.find('.unbind').unbind()
      @$el.empty().append "<li class='empty'>#{@options.emptyLabel}</li>"
      # makes value an array
      linked = @options.value
      linked = [linked] if linked? and !Array.isArray linked

      return unless Array.isArray(linked) and linked.length > 0
      @$el.empty()


      # creates a widget for each linked object
      for link, i in linked
        continue unless link? and link isnt ''
        # instanciate the widget
        line = $("<li data-idx='#{i}'></li>").appendTo @$el
        $('<span></span>').instanceDetails(
          value: link,
          tooltipFct: @options.tooltipFct,
          dndType: @options.dndType
        ).appendTo line
        # adds buttons if needed
        continue unless @options.withUnbind
        $('<a class="unbind"></a>')
          .appendTo(line)
          .attr('title', i18n.instanceList.unbind)
          .on('click', @_onUnbind)
          .button
            icons: primary: 'ui-icon x-small unbind'
            text: false

    # **private**
    # Drop accept handler. Allows or denu operation inside the widget.
    #
    # @param draggable [Object] drag'n drop operation source
    # @return true if operation is possible, false otherwise
    _onAccept: (draggable) =>
      data = draggable.data('draggable')?.helper?.data 'instance'
      return false unless data? and data.constructor.name?
      @options.accepted.length is 0 or data.constructor.name in @options.accepted
  
    # **private**
    # Drop handler. Adds or replace the dropped object inside linked objects
    # 
    # @param event [Event] Drop event.
    # @param details [Object] drop operation details:
    # @option details draggable [Object] drag'n drop source
    # @option details helper [Object] the moved object
    # @option position [Object] the current position of the drag helper (absolute)
    _onDrop: (event, details) =>
      # gets the dropped data
      instance = details.helper.data 'instance'
      return unless instance?
      # replace existing instance if only one displayed
      if @options.onlyOne
        @options.value = instance
      else
        @options.value.push instance

      # re-creates the rendering, once the drop operation is finished
      _.defer =>
        @_create()
        @$el.trigger 'change', @options.value

    # **private**
    # Click handler. Find the closest item and triggers `click` if found
    # 
    # @param event [Event] list click event
    _onClick: (event) =>
      target = $(event.target).closest 'li'
      instance = target.find('.instance-details').data('instanceDetails')?.options.value
      return unless instance?
      # stop event and triggers click
      event.preventDefault()
      event.stopImmediatePropagation()
      @$el.trigger 'click', instance
    
    # **private**
    # Click handler on unbind button. Removes object from list and re-creates rendering.
    # 
    # @param event [Event] unbind buttont click event
    _onUnbind: (event) =>
      event.preventDefault()
      event.stopImmediatePropagation()
      # only one displayed: removes value
      if @options.onlyOne
        @options.value = null
      else
        idx = $(event.target).closest('li').data 'idx'
        # removes object from list
        @options.value.splice idx, 1
      # refresh rendering
      @_create()
      @$el.trigger 'change', @options.value

  # widget declaration
  InstanceList._declareWidget 'instanceList',

    # Currently displayed object list. Read-only: use setOption('value') to change.
    value: null
    
    # Restrict list size to 1
    onlyOne: false
    
    # Indicate wether or not to add unlink button. Read-only: use setOption('withUnbind') to change.
    withUnbind: true
      
    # Tooltip generator used inside instanceDetails widgets. 
    # This function takes displayed object as parameter, and must return a string, used as tooltip.
    # If null is returned, no tooltip displayed
    tooltipFct: null
    
    # Accepted drag'n drop scope. Null to disable drop inside widget
    dndType: null

    # Restricted type of dropped objects. Empty means no restriction
    accepted: []
      
    # label used when list is empty
    emptyLabel: i18n.instanceList.empty