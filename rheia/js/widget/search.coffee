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
  'i18n!nls/widget'
  'queryparser'
  'utils/utilities'
  'widget/baseWidget'
  'widget/typeTree'
], ($, _, i18n, parser, utils) ->
  
  # The search widget displays a search field, a line for results number, and a popup
  # for search results.
  # the `search` event is triggered when a search need to be performed, with query as parameter.
  # the `click` event is triggered when clicking an item in results (with category and id in parameter)
  $.widget 'rheia.search', $.rheia.baseWidget,
    
    options:  
      
      # Help text displayed when hovering the help icon
      helpTip: ''

      # Displayed results. Read-only: use setOption('results') to change.
      results: []

      # duration of result toggle animations
      animDuration: 250

    # **private**
    # avoid triggering multiple searchs.
    _searchPending: false

    # **private**
    # DOM node of displayed results.
    _results: null

    # **private**
    # input search timeout.
    _searchTimout: null

    # **private**
    # result hide timeout.
    _hideTimeout: null

    # **private**
    # result show timeout.
    _showTimeout: null

    # **private**
    # For unbind purposes
    _changeCallback : null
    _kindCallback: null

    # **private**
    # Allow to distinguish search triggered by refresh.
    _refresh: false

    # Frees DOM listeners
    destroy: ->
      rheia.router.off 'modelChanged', @_changeCallback
      rheia.router.off 'kindChanged', @_kindChanged
      @element.unbind()
      @element.find('input, .ui-icon-search').unbind()
      $.Widget.prototype.destroy.apply @, arguments

    # Parse the input query, and if correct, trigger the server call.
    #
    # @param force [Boolean] force the request sending, even if request is empty. But invalid request cannot be forced.
    triggerSearch: (force = false) ->
      # do NOT send multiple search in the same time
      return if @_searchPending
      @element.removeClass('invalid').find('.error').hide()

      # parse query
      try 
        query = parser.parse @element.find('input').val()
      catch exc
        return @element.addClass('invalid').find('.error').show().text exc

      # avoid empty queries unless told to do
      return if query is '' and !force
      @_searchPending = true
      clearTimeout @_searchTimout if @_searchTimout?

      # hide results
      @_onHideResults()
      # no query: just empties results
      return @setOption 'results', [] if query is ''
      # or trigger search
      console.log "new search of #{JSON.stringify query}"
      @_trigger 'search', null, query

    # **private**
    # Builds rendering
    _create: ->
      # general change handler: refresh search
      @_changeCallback = => 
        @_refresh = true
        @triggerSearch()
      rheia.router.on 'modelChanged', @_changeCallback
      
      # Executable kind changed: refresh results
      @_kindChanged = => 
        return unless Array.isArray(@options.results) and @options.results.length
        @_results.typeTree 'option', 'content', @options.results
      rheia.router.on 'kindChanged', @_kindChanged

      @element.addClass('search').append """<input type="text"/>
        <div class="ui-icon ui-icon-search"></div>
        <div class="ui-icon small help"></div>
        <div class="nb-results"></div>
        <div class="error"></div>
        <div class="results"></div>"""

      # help tooltip
      @element.find('.help').attr 'title', @options.helpTip
      
      # bind on input changes and click events
      @element.find('input').keyup (event) => @_onChange event
      @element.find('.ui-icon-search').click (event) => @triggerSearch()
      @_results = @element.find('.results').hide().typeTree
        openAtStart: true
        hideEmpty: true
        openElement: (event, category, id) => @_trigger 'openElement', event, category, id
        removeElement: (event, category, id) => @_trigger 'removeElement', event, category, id
      
      # toggle results visibility
      @element.hover (event) =>
        # stop closure if necessary
        clearTimeout @_hideTimeout if @_hideTimeout?
        @_onShowResults()
      , (event) =>
        @_hideTimeout = setTimeout (=> @_onHideResults()),1000

    # **private**
    # Method invoked when the widget options are set. Update popup if `results` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.Widget.prototype._setOption.apply @, arguments unless key in ['results']
      switch key
        when 'results'
          # checks that results are an array
          return unless Array.isArray value
          @_searchPending = false
          @options.results = value

          # displays results number
          html = ''
          if @options.results.length is 0
            html = i18n.search.noResults
          else if @options.results.length is 1
            html = i18n.search.oneResult
          else
            html = _.sprintf i18n.search.nbResults, @options.results.length
          @element.find('.nb-results').html html

          # set max height because results are absolutely positionned
          @_results.css 'max-height', @element.offsetParent().height()*0.8
          # update tree content
          @_results.typeTree 'option', 'content', @options.results

          @_onShowResults() unless @_refresh
          @_refresh = false

    # **private**
    # Displays the result popup, with a slight delay to avoir openin if mouse leave the widget.
    _onShowResults: ->
      if @options.results?.length > 0 and @_showTimeout is null
        # show results with slight delay
        @_showTimeout = setTimeout =>
          @_results.show().transition {opacity:1}, @options.animDuration, =>
            # in case of collapsing hide/show calls
            @_showTimeout = null
            @_results.show() unless @_results.is ':visible'
        , 200

    # **private**
    # Hides the result popup, or cancel opening if necessary.
    _onHideResults: ->
      if @options.results?.length > 0 and @_results.is ':visible'
        # cancels opening 
        if @_showTimeout?
          clearTimeout @_showTimeout 
          @_showTimeout = null
        else
          @_results.transition {opacity: 0}, @options.animDuration, => @_results.hide()

    # **private**
    # input change handler: waits a little before sending to server unless input is ENTER
    #
    # @param event [Event] keyboard event
    _onChange: (event) ->
      clearTimeout @_searchTimout if @_searchTimout?
      # manually triggers research
      return @triggerSearch true if event.keyCode is $.ui.keyCode.ENTER
      # defer search
      @_searchTimout = setTimeout (=> @triggerSearch()), 1000