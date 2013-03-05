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
  'utils/validators'
  'view/edition/Explorer'
  'view/edition/ItemType'
  'view/edition/EventType'
  'view/edition/FieldType'
  'view/edition/Map'
  'view/edition/Rule'
  'view/edition/TurnRule'
  'view/edition/Script'
  'widget/search'
], ($, TabPerspective, i18n, i18nEdition, template, utils, validators, Explorer, 
    ItemTypeView, EventTypeView, FieldTypeView, MapView, RuleView, TurnRuleView, ScriptView) ->

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
      @bindTo app.router, 'searchResults', (err, instances, results) =>
        return if instances is true
        if err?
          # displays an error
          @_searchWidget.setOption 'results', []
          return utils.popup i18n.titles.serverError, _.sprintf(i18n.msgs.searchFailed, err), 'cancel', [text: i18n.buttons.ok]
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
      ).on('search', (event, query) -> app.searchService.searchTypes query
      ).on('openElement', (event, details) -> app.router.trigger 'open', details.category, details.id
      ).on('removeElement', (event, details) -> app.router.trigger 'remove', details.category, details.id
      ).data 'search'


      # general change handler: trigger again search
      @bindTo app.router, 'modelChanged', (kind, model) => 
        @_searchWidget?.triggerSearch true if model?._className in ['ItemType', 'EventType', 'FieldType', 'Map', 'Executable']
      
      # Executable kind changed: refresh search results
      @bindTo app.router, 'kindChanged', => 
        prev = @_searchWidget?.options.results
        return unless Array.isArray(prev) and prev.length
        @_searchWidget.setOption 'results', prev

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
      return null unless type in ['FieldType', 'ItemType', 'EventType', 'Rule', 'TurnRule', 'Script', 'Map']
      # creates the relevant view
      view = null
      unless id?
        # choose an id within a popup
        popup = utils.popup(i18n.titles.chooseId, i18n.msgs.chooseId, 'question', [
          text: i18n.buttons.ok
          icon: 'valid'
          click: =>
            # Do not proceed unless no validation error
            validator.validate()
            return false unless validator.errors.length is 0
            id = input.val()
            # ask server if id is free
            app.sockets.admin.once 'isIdValid-resp', (err) =>
              if err
                return popup.find('.errors').empty().append i18n.msgs.alreadyUsedId
              validator.dispose()
              # now we can opens the view tab
              popup.dialog 'close'
              @_onOpenElement type, id
            app.sockets.admin.emit 'isIdValid', id
            false
        ,
          text: i18n.buttons.cancel
          icon: 'cancel'
          click: -> validator.dispose()
        ],
        1).addClass 'name-choose-popup'

        # adds a text field and an error field above it
        popup.append """<div class="id-container">
            <label>#{i18n.labels.id}#{i18n.labels.fieldSeparator}</label>
            <input type='text' class='id'/>
          </div>
          <div class='errors'></div>"""
        input = popup.find '.id'

        # creates the validator
        validator = new validators.Regexp 
          required: true
          invalidError: i18n.msgs.invalidId
          regexp: i18n.constants.uidRegex
        , i18n.labels.id, input, 'keyup' 

        # displays error on keyup. Binds after validator creation to validate first
        input.focus()
        input.on 'keyup', (event) =>
          # displays error on keyup
          popup.find('.errors').empty()
          if validator.errors.length
            popup.find('.errors').append error.msg for error in validator.errors
          if event.which is $.ui.keyCode.ENTER
            popup.parent().find('.ui-dialog-buttonset > *').eq(0).click()
        return null

      # id is known, opens it
      switch type
        when 'FieldType' then view = new FieldTypeView id
        when 'ItemType' then view = new ItemTypeView id
        when 'EventType' then view = new EventTypeView id
        when 'Rule' then view = new RuleView id
        when 'TurnRule' then view = new TurnRuleView id
        when 'Script' then view = new ScriptView id
        when 'Map' then view = new MapView id
      view