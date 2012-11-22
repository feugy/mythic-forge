###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
     at your option any later version.

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
  'widget/base'
],  ($, Base) ->

  # The toggleable widget pops-up at screen to display something, and then hides
  # when clicking somewhere else, or when manually destroyed.
  # It can be automatically closed if mouse does not hover it.
  class Toggleable extends Base  
          
    # Closure timeout
    _closeTimeout: null
    
    # generated id for click handlers on document
    _id: null
        
    # **private**
    # Rendering building
    constructor: (element, options) ->
      super element, options
      
      @$el.addClass 'toggleable'
      @_id =  parseInt Math.random()*1000000000
      if @options.initialyClosed
        @options.open = false
        @$el.hide()

    # opens the widget, with an animation.
    #
    # @param left [Number] Mouse position: absolute left coordinate
    # @param top [Number] Mouse position: absolute top coordinate
    open: (left, top) =>
      # stops timeout
      @_onMouseIn()

      # positionnate relatively to the widget parent, taking scroll into account
      # element must not be hidden
      parent = @$el.show().offsetParent()
      @$el.hide()
      parentOffset = parent.offset() or top:0, left: 0
      left -= parentOffset.left + (parent.scrollLeft() or 0)
      top -= parentOffset.top + (parent.scrollTop() or 0)

      # Widget and window inner sizes
      dim = 
        w: @$el.outerWidth true
        h: @$el.outerHeight true

      win = 
        w: parent.scrollLeft() + parent.outerWidth true
        h: parent.scrollTop() + parent.outerHeight true

      top -= top+dim.h+10 - win.h if top+dim.h > win.h
      left -= left+dim.w+10 - win.w if left+dim.w > win.w

      @options.open = true
      @$el.css(
        left: left
        top: top
      ).stop().fadeIn @options.animationSpeed
              
      if @options.closeOnOut
        # attaches hover handler and automatic close if nothing happens
        @$el.on 'mouseenter.toggleable', => @_onMouseIn()
        @$el.on 'mouseleave.toggleable', => @_onMouseOut()
        @_closeTimeout = setTimeout (=> @_onMouseOut()), @options.firstShowDelay
      
      if @options.closeOnClickDocument
        # closes on document click
        $(document).on "click.toggleable.#{@_id}", => @close()
    
    # Closes widget with an animation
    close: =>
      @options.open = false
      @$el.off('.toggleable').stop().fadeOut @options.animationSpeed
      $(document).off ".toggleable.#{@_id}"
      if @options.destroyOnClose
        @$el.remove() 
        @destroy()

    # Destroyer: free dom handlers
    dispose: =>
      @$el.off '.toggleable'
      $(document).off ".toggleable.#{@_id}"
      # superclass call
      super()

    # **private**
    # Mouse leave handler. Closes widget after a timeout
    _onMouseOut: =>
      @_closeTimeout = setTimeout (=> @close()), @options.closeDelay

    # **private**
    # Mouse enter handler. Cancels close timer
    _onMouseIn: =>
      return unless @_closeTimeout?
      clearTimeout @_closeTimeout
      @_closeTimeout = null

  # widget declaration
  Toggleable._declareWidget 'toggleable', 

    # Animations speed in millis.
    animationSpeed: 250
    
    # Widget open status.
    # Read-only: use `open()` and `close()` to modify
    open: true
    
    # Widget open status after creation.
    initialyClosed: true
    
    # If true, widget will close when mouse ceases to hover it
    closeOnOut: true
     
    # If true, closes the widget when clicking in the document
    closeOnClickDocument: true

    # An automatic closure delay, cancelled if mouse hover the widget.
    firstShowDelay: 4000
   
    # Delay before closure when mouse stops to hover the widget.
    # Cancelled if mouse hover the widget.
    closeDelay: 1000
    
    # If true, widget is destroyed after close
    destroyOnClose: false