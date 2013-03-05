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
  'widget/base'
  'widget/typeTree'
  'widget/instanceTree'
], ($, _, i18n, parser, utils, Base) ->

  # once search is used, increment the jquery-ui overley z-index
  $.ui.dialog.maxZ = 5001
  
  # The search widget displays a search field, a line for results number, and a popup
  # for search results.
  # the `search` event is triggered when a search need to be performed, with query as parameter.
  # the `click` event is triggered when clicking an item in results (with category and id in parameter)
  class Search extends Base
    
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
    # Allow to distinguish search triggered by refresh.
    _refresh: false

    # **private**
    # Stores the name of the tree widget used
    _treeWidget: null

    # Builds rendering
    constructor: (element, options) ->
      super element, options

      @_treeWidget = if @options.isType then 'typeTree' else 'instanceTree'

      @$el.addClass('search').append """<input type="text"/>
        <div class="ui-icon ui-icon-search"></div>
        <div class="ui-icon small help"></div>
        <div class="nb-results"></div>
        <div class="error"></div>
        <div class="results"></div>"""

      # help tooltip
      @$el.find('.help').attr 'title', @options.helpTip
      
      # bind on input changes and click events
      @$el.find('input').keyup @_onChange
      @$el.find('.ui-icon-search').click (event) => @triggerSearch()
      @_results = @$el.find('.results').hide()[@_treeWidget]
        openAtStart: true
        hideEmpty: true
        tooltipFct: @options.tooltipFct
        dndType: @options.dndType
      
      # toggle results visibility
      @$el.hover (event) =>
        # stop closure if necessary
        clearTimeout @_hideTimeout if @_hideTimeout?
        @_onShowResults()
      , (event) =>
        @_hideTimeout = setTimeout (=> @_onHideResults()),1000

    # Frees DOM listeners
    dispose: =>
      @$el.find('input, .ui-icon-search').off()
      super()

    # Parse the input query, and if correct, trigger the server call.
    #
    # @param refresh [Boolean] indicate that the search is a refreshal: results will not be hidding/shown automatically
    # @param force [Boolean] force the request sending, even if request is empty. But invalid request cannot be forced.
    triggerSearch: (refresh = false, force = false) =>
      # do NOT send multiple search in the same time
      return if @_searchPending
      @$el.removeClass('invalid').find('.error').hide()

      # parse query
      try 
        query = parser.parse @$el.find('input').val()
      catch exc
        return @$el.addClass('invalid').find('.error').show().text exc

      # avoid empty queries unless told to do
      return if query is '' and !force
      @_searchPending = true
      clearTimeout @_searchTimout if @_searchTimout?

      # hide results
      @_refresh = refresh
      @_onHideResults() unless @_refresh
      # no query: just empties results
      return @setOption 'results', [] if query is ''
      # or trigger search
      console.log "new search of #{JSON.stringify query}"
      @$el.trigger 'search', query

    # Method invoked when the widget options are set. Update popup if `results` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) =>
      return unless key in ['results']
      switch key
        when 'results'
          # checks that results are an array
          return unless Array.isArray value
          @_searchPending = false
          @options.results = value

          # displays results number
          @_displayResultNumber()

          # set max height because results are absolutely positionned
          @_results.css 'max-height', @$el.offsetParent().height()*0.75
          # update tree content
          @_results[@_treeWidget] 'setOption', 'content', @options.results

          @_onShowResults() unless @_refresh
          @_refresh = false

    # display result number
    _displayResultNumber: =>
      html = ''
      if @options.results.length is 0
        html = i18n.search.noResults
      else if @options.results.length is 1
        html = i18n.search.oneResult
      else
        html = _.sprintf i18n.search.nbResults, @options.results.length
      @$el.find('.nb-results').html html

    # **private**
    # Displays the result popup, with a slight delay to avoir openin if mouse leave the widget.
    _onShowResults: =>
      if @options.results?.length > 0 and @_showTimeout is null and @_results.is ':hidden'
        # show results with slight delay
        @_showTimeout = setTimeout =>
          @_results.show().transition {opacity:1}, @options.animDuration, =>
            # in case of collapsing hide/show calls
            @_showTimeout = null
            @_results.show() unless @_results.is ':visible'
        , 200

    # **private**
    # Hides the result popup, or cancel opening if necessary.
    _onHideResults: =>
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
    _onChange: (event) =>
      clearTimeout @_searchTimout if @_searchTimout?
      # manually triggers research
      return @triggerSearch false, true if event.keyCode is $.ui.keyCode.ENTER
      # defer search
      @_searchTimout = setTimeout (=> @triggerSearch()), 1000

  # widget declaration
  Search._declareWidget 'search', 

    # Help text displayed when hovering the help icon
    helpTip: ''

    # Displayed results. Read-only: use setOption('results') to change.
    results: []

    # True to display types, false to display instances
    isType: true
      
    # Tooltip generator used inside results (instance only). 
    # This function takes displayed object as parameter, and must return a string, used as tooltip.
    # If null is returned, no tooltip displayed
    tooltipFct: null
    
    # Used scope for instance drag'n drop operations. Null to disable drop outside widget
    dndType: null

    # Duration of result toggle animations
    animDuration: 250