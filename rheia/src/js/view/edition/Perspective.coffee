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
  'jquery'
  'view/TabPerspective'
  'i18n!nls/common'
  'i18n!nls/edition'
  'text!tpl/editionPerspective.html'
  'utils/utilities'
  'view/edition/Explorer'
  'view/edition/ItemType'
  'view/edition/EventType'
  'view/edition/FieldType'
  'view/edition/Map'
  'view/edition/Rule'
  'view/edition/TurnRule'
  'widget/search'
], ($, TabPerspective, i18n, i18nEdition, template, utils, Explorer, 
    ItemTypeView, EventTypeView, FieldTypeView, MapView, RuleView, TurnRuleView) ->

  i18n = $.extend true, i18n, i18nEdition

  # The edition perspective manages types, rules and maps
  class EditionPerspective extends TabPerspective
    
    # rendering event mapping
    events: 
      'click .new-button-menu > *': '_onNewElement'

    # **private**
    # View's mustache template
    _template: template

    # **private**
    # Explorer view
    _explorer: null

    # **private**
    # search widget
    _searchWidget: null
   
    # The view constructor.
    constructor: ->
      super 'edition'

      # construct explorer
      @_explorer = new Explorer()

      # bind to global events
      @bindTo rheia.router, 'searchResults', (err, results) =>
        if err?
          # displays an error
          @_searchWidget.setOption 'results', []
          return utils.popup i18n.titles.serverError, _.sprintf(i18n.msgs.searchFailed, err), 'cancel', [text: i18n.labels.ok]
        @_searchWidget.setOption 'results', results

    # The `render()` method is invoked by backbone to display view content at screen.
    # Draws the login form.
    render: =>
      super()
      # render the explorer on the left
      @$el.find('> .left').append @_explorer.render().$el

      # new button and its dropdown menu
      @$el.find('> .right .new-button').button(icons: secondary: 'ui-icon-triangle-1-s').on 'click', (event) => 
          event.preventDefault(); @$el.find('.new-button-menu').addClass 'open'
      @$el.find('.new-button-menu').on 'mouseleave click', -> $(this).removeClass 'open'

      # creates a search widget
      @_searchWidget = @$el.find('> .left .search').search(
        helpTip: i18n.tips.searchTypes
        search: (event, query) -> rheia.searchService.searchTypes query
        open: (event, details) -> rheia.router.trigger 'open', details.category, details.id
      ).data 'search'

      # for chaining purposes
      @

    # **private**
    # Provide template data for rendering
    #
    # @return an object used as template data
    _getRenderData: =>
      i18n:i18n

    # **private**
    # Ask to creates a new element when a new button menu item was clicked.
    #  
    # @param event [Event] new button menu item click event.
    _onNewElement: (event) =>
      @_onOpenElement $(event.target).closest('li').data('class'), null

    # **private**
    # Delegate method the instanciate a view from a type and an id, either
    # when opening an existing view, or when creating a new one.
    #
    # @param type [String] type of the opened/created instance
    # @param id [String] optional id of the opened instance. Null for creations
    # @return the created view, or null to cancel opening/creation
    _constructView: (type, id) =>
      # creates the relevant view
      view = null
      switch type
        when 'FieldType' then view = new FieldTypeView id
        when 'ItemType' then view = new ItemTypeView id
        when 'EventType' then view = new EventTypeView id
        when 'Rule' then view = new RuleView id
        when 'TurnRule' then view = new TurnRuleView id
        when 'Map' then view = new MapView id
      view