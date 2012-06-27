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
###
'use strict'

define [
  'backbone'
  'jquery'
  'i18n!nls/edition'
  'view/edition/Explorer'
  'view/edition/ItemType'
], (Backbone, $, editionLabels, Explorer, ItemTypeView) ->

  editionLabels = _.extend {}, editionLabels

  # The edition perspective manages types, rules and maps
  class EditionPerspective extends Backbone.View
    
    # rendering event mapping
    events: 
      'click .new-button-menu > *': '_onNewElement'
      # do not use click because jQuery-ui tabs prevent them in nav bar.
      'mouseup .ui-tabs-nav .ui-icon-close': '_onCloseTab'

    # **private**
    # views displayed into the tab container.
    _views: []

    # **private**
    # the tab widget containing views.
    _tabs: null

    # **private**
    # bypass the close confirmation when closing a view. Used when object was removed.
    _forceClose: false
   
    # The view constructor.
    #
    # @param router [Router] the event bus
    constructor: (@router) ->
      super {tagName: 'div', className:'edition perspective'}

      # construct explorer
      @explorer = new Explorer @router
      @router.on 'open', @_onOpenElement

    # The `render()` method is invoked by backbone to display view content at screen.
    # Draws the login form.
    render: =>
      # creates the two columns
      @$el.append """<div class="row">
          <div class="left cell"></div>
          <div class="right cell">
            <div>
              <a href="#" data-menu="new-button-menu" class="new-button">#{editionLabels.buttons.new}</a>
              <ul class="menu new-button-menu">
                <li><i class="new itemType"></i>#{editionLabels.buttons.newItemType}</li>
              </ul>
            </div>
            <div class=\"ui-tabs\">
              <ul></ul>
            </div>
          </div>
        </div>"""
      # render the explorer on the left
      @$el.find('.cell.left').append @explorer.render().$el
      # instanciates a tab widget
      @_tabs = @$el.find('.cell.right .ui-tabs').tabs({
          # template with close button
          tabTemplate: """ <li>
              <a href="\#{href}">
                <i class="icon"></i>
                <span class="content">\#{label}</span>
                <i class="ui-icon ui-icon-close"></i>
              </a>
            </li> """
        })
        # handlers
        .bind('tabsadd', @_onTabAdded)
        .data 'tabs'

      # new button and its dropdown menu
      @$el.find('.right .new-button').button({icons: {secondary: 'ui-icon-triangle-1-s'}})
        .on 'click', (event) =>
          event.preventDefault()
          @$el.find('.new-button-menu').addClass 'open'
      @$el.find('.new-button-menu').on 'mouseleave click', -> $(this).removeClass 'open'

      # for chaining purposes
      return @

    # tries to close a tab, if the corresponding views allowed it.
    #
    # @param view [Object] the corresponding view
    tryCloseTab: (view) =>
      # if closure is allowed, removes the tab
      if @_forceClose or view.canClose()
        @_forceClose = false
        idx = @_indexOfView view.getId() 
        return if idx is -1
        console.log "view #{view.getTitle()} closure"
        @_views.splice idx, 1
        @_tabs?.remove idx
      else
        console.log "view #{view.getTitle()} cancels its closure"

    # **private**
    # Ask to creates a new element when a new button menu item was clicked.
    #  
    # @param event [Event] new button menu item click event.
    _onNewElement: (event) =>
      category = _.capitalize $(event.target).closest('li').find('i').attr('class').replace('new', '').trim()
      @_onOpenElement category, null

    # **private**
    # This method is invoked when an element must be shwoned in a tab.
    #  
    # @param type [String] opened element className.
    # @param id [String] opened element id, or null for a creation.
    _onOpenElement: (type, id) =>
      # first check if the view is not already opened.
      if id?
        idx = @_indexOfView id
        return @_tabs.select idx unless idx is -1

      # creates the relevant view
      view = null
      switch type
        when 'ItemType' then view = new ItemTypeView @router, id
        else return

      @_views.push view
      @_tabs.add '#tabs-'+view.getId(), view.getTitle()

    # **private**
    # Handler invoked when a tab was added to the widget. Render the view inside the tab.
    #
    # @param event [Event] tab additon event
    # @param ui [Object] tab container 
    _onTabAdded: (event, ui) =>
      # gets the added view from the internal array
      id = $(ui.tab).attr('href').replace '#tabs-', ''
      view = _.find @_views, (view) -> view.getId() is id

      # add the class name to the icon
      $(ui.tab).find('.icon').addClass view.className
      # render the corresponding view inside the tab and display it
      $(ui.panel).append view.render().$el
      @_tabs.select @_indexOfView id

    # **private**
    # trigger the tab close procedure when clicking on the relevant icon.
    #
    # @param event [Event] click event on the close icon
    _onCloseTab: (event) =>
      event.preventDefault()
      id = $(event.target).closest('a').attr('href').replace '#tabs-', ''
      idx = @_indexOfView id
      return unless idx isnt -1
      console.log "try to close tab for view #{@_views[idx].getTitle()}"
      @tryCloseTab @_views[idx]

    # **private**
    # Finds the position of a view inside the `_views` array, with its id.
    #
    # @param id [String] the searched view's id.
    # @return index of the corresponding view, of -1
    _indexOfView: (id) =>
      idx = (i for view, i in @_views when view.getId() is id)
      if idx.length is 1 then idx[0] else -1

  return EditionPerspective