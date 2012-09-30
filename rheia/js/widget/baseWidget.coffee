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
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

define [
  'jquery'
  'jquery-ui'
],  ($) ->

  # This classes defines common methods to widgets.
  $.widget 'rheia.baseWidget', 

    # **private**
    # Array of bounds between targets and the view, that are unbound by `destroy`
    # Stores an array for each bond: frist the emitter, then the event and at last the callback
    _bounds: []

    # **private**
    # Initialize bound array
    _create: ->
      @_bounds = []
  
    # Allows to set a widget option.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option
    setOption: (key, value) -> @_setOption key, value

    # Allows to bound a callback of this widget to the specified emitter
    # bounds are keept and automatically unbound by the `destroy` method.
    #
    # @param emitter [Backbone.Event] the emitter on which callback is bound
    # @param events [String] events on which the callback is bound
    # @parma callback [Function] the bound callback
    bindTo: (emitter, events, callback) ->
      emitter.on events, callback
      @_bounds.push [emitter, events, callback]
      
    # Unbounds a callback of this widget from the specified emitter
    #
    # @param emitter [Backbone.Event] the emitter on which callback is unbound
    # @param events [String] event on which the callback is unbound
    unboundFrom: (emitter, event) ->
      for spec, i in @_bounds when spec[0] is emitter and spec[1] is event
        spec[0].off spec[1], spec[2]
        @_bounds.splice i, 1
        break

    # Frees registered handlers
    destroy: ->
      # automatically remove bound callback
      spec[0].off spec[1], spec[2] for spec in @_bounds
      $.Widget::destroy.apply @, arguments