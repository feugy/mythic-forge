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
  'underscore'
  'underscore.string'
  'backbone'
  'hogan'
], (_, _string, Backbone, Hogan) ->

  # mix in non-conflict functions to Underscore namespace if you want
  _.mixin _string.exports()
  _.mixin
    includeStr: _string.include
    reverseStr: _string.reverse

  # enhance Backbone views with close() mechanism
  _.extend Backbone.View.prototype, 

    # **protected**
    # For views that wants templating, put their the string version of a mustache template,
    # that will be compiled with Hogan
    _template: null

    # **private**
    # Array of bounds between targets and the view, that are unbound by `destroy`
    _bounds: []

    # overload the initialize method to bind `destroy()`
    initialize: ->
      # initialize to avoid static behaviour
      @_bounds = []
      # bind to remove element to call the close method.
      @$el.bind 'remove', => @dispose()

    # Allows to bound a callback of this view to the specified emitter
    # bounds are keept and automatically unbound by the `destroy` method.
    #
    # @param emitter [Backbone.Event] the emitter on which callback is bound
    # @param events [String] events on which the callback is bound
    # @parma callback [Function] the bound callback
    bindTo: (emitter, events, callback) ->
      emitter.on events, callback
      @_bounds.push [emitter, events, callback]

    # The destroy method correctly free DOM  and event handlers
    # It must be overloaded by subclasses to unsubsribe events.
    dispose: ->
      # automatically remove bound callback
      spec[0].off spec[1], spec[2] for spec in @_bounds
      # unbind DOM callback
      @$el.unbind()
      # remove rendering
      @remove()
      @trigger 'dispose', @

    # The `render()` method is invoked by backbone to display view content at screen.
    # if a template is defined, use it
    render: () ->
      # template rendering
      if @_template? 
        # first compilation if necessary  
        @_template = Hogan.compile @_template if _.isString @_template
        # then rendering
        @$el.empty().append @_template.render @_getRenderData()
      # for chaining purposes
      @

    # **protected**
    # This method is intended to by overloaded by subclass to provide template data for rendering
    #
    # @return an object used as template data (this by default)
    _getRenderData: -> @
