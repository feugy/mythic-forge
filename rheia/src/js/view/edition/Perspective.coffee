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
  'i18n!nls/edition'
  'view/edition/Explorer'
  'view/edition/ItemType'
  'view/edition/Rule'
], (i18n, Explorer, ItemTypeView, RuleView) ->

  i18n = _.extend {}, i18n

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
    # special tab widget containing actions bars.
    _actionBars: null

    # **private**
    # bypass the close confirmation when closing a view. Used when object was removed.
    _forceClose: false
   
    # The view constructor.
    constructor: () ->
      super({tagName: 'div', className:'edition perspective'})

      # construct explorer
      @explorer = new Explorer()
      @bindTo(rheia.router, 'open', @_onOpenElement)
      # bind shortcuts
      $(document).bind("keydown.#{@cid}", {keys:'ctrl+s', includeInputs:true}, @_onSaveHotKey)
        .bind("keydown.#{@cid}", {keys:'ctrl+shift+d', includeInputs:true}, @_onRemoveHotKey)
        .bind("keydown.#{@cid}", {keys:'ctrl+q', includeInputs:true}, @_onCloseHotKey)

    # The view destroyer: unbinds shortcuts
    destroy: () =>
      # removes shortcuts
      $(document).unbind(".#{@cid}")
      super()

    # The `render()` method is invoked by backbone to display view content at screen.
    # Draws the login form.
    render: () =>
      # creates the two columns
      @$el.empty().append("""<div class="row">
          <div class="left cell"></div>
          <div class="right cell">
            <div>
              <a href="#" data-menu="new-button-menu" class="new-button">#{i18n.buttons.new}</a>
              <ul class="menu new-button-menu">
                <li data-class="ItemType"><i class="new item-type"></i>#{i18n.buttons.newItemType}</li>
                <li data-class="Rule"><i class="new rule"></i>#{i18n.buttons.newRule}</li>
              </ul>
              <div class="ui-tabs action-bars">
                <ul></ul>
              </div>
            </div>
            <div class="ui-tabs views">
              <ul></ul>
            </div>
          </div>
        </div>""")
      # render the explorer on the left
      @$el.find('.cell.left').append(@explorer.render().$el)
      # instanciates a tab widget for views
      @_tabs = @$el.find('.cell.right .ui-tabs.views').tabs({
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
        .bind('tabsselect', (event, ui) => @_actionBars?.select(ui.index))
        .data('tabs')
      # instanciates a tab widget for action bars
      @_actionBars = @$el.find('.cell.right .ui-tabs.action-bars').tabs().data('tabs')

      # new button and its dropdown menu
      @$el.find('.right .new-button').button({icons: {secondary: 'ui-icon-triangle-1-s'}})
        .on('click', (event) => event.preventDefault(); @$el.find('.new-button-menu').addClass('open'))
      @$el.find('.new-button-menu').on('mouseleave click', () -> $(this).removeClass('open'))

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
        console.log("view #{view.getTitle()} closure")
        @_views.splice(idx, 1)
        @_tabs?.remove(idx)
        @_actionBars?.remove(idx)
      else
        console.log("view #{view.getTitle()} cancels its closure")

    # **private**
    # Finds the position of a view inside the `_views` array, with its id.
    #
    # @param id [String] the searched view's id.
    # @return index of the corresponding view, of -1
    _indexOfView: (id) =>
      idx = (i for view, i in @_views when view.getId() is id)
      if idx.length is 1 then idx[0] else -1

    # **private**
    # Ask to creates a new element when a new button menu item was clicked.
    #  
    # @param event [Event] new button menu item click event.
    _onNewElement: (event) =>
      @_onOpenElement($(event.target).closest('li').data('class'), null)

    # **private**
    # This method is invoked when an element must be shwoned in a tab.
    #  
    # @param type [String] opened element className.
    # @param id [String] opened element id, or null for a creation.
    _onOpenElement: (type, id) =>
      # first check if the view is not already opened.
      if id?
        idx = @_indexOfView id
        return @_tabs.select(idx) unless idx is -1

      # creates the relevant view
      view = null
      switch type
        when 'ItemType' then view = new ItemTypeView(id)
        when 'Rule' then view = new RuleView(id)
        else return

      @_views.push(view)
      @_tabs.add('#tabs-'+view.getId(), view.getTitle())

    # **private**
    # Handler invoked when a tab was added to the widget. Render the view inside the tab.
    #
    # @param event [Event] tab additon event
    # @param ui [Object] tab container 
    _onTabAdded: (event, ui) =>
      # gets the added view from the internal array
      id = $(ui.tab).attr('href').replace('#tabs-', '')
      view = _.find(@_views, (view) -> view.getId() is id)
      
      # bind changes to update tab
      view.on('change', () =>
        tab = @_tabs.element.find("a[href=#tabs-#{view.getId()}] .content")
        # toggle Css class modified wether we can save the view
        tab.toggleClass('modified', view.canSave())
        # updates title
        tab.html(view.getTitle()))
      # bind close we view ask for it
      view.on('close', () => @tryCloseTab(view))
      # bind Id affectation, to update tabs' ids when the model is created
      view.on('affectId', (tempId, newId) =>
        # updates view tab
        link = @_tabs.element.find("a[href=#tabs-#{tempId}]")
        link.attr('href', "#tabs-#{newId}")
        link.closest('li').attr('aria-controls', "tabs-#{newId}")
        # updates view panel
        @_tabs.element.find("#tabs-#{tempId}").attr('id', "tabs-#{newId}")
        # updates action bar tab
        link = @_actionBars.element.find("a[href=#actionBar-#{tempId}]")
        link.attr('href', "#actionBar-#{newId}")
        link.closest('li').attr('aria-controls', "actionBar-#{newId}")
        # updates action bar panel
        @_actionBars.element.find("#actionBar-#{tempId}").attr('id', "actionBar-#{newId}"))

      # adds the action bar to the other ones
      @_actionBars.add("#actionBar-#{view.getId()}", view.getId(), ui.index)
      $(@_actionBars.panels[ui.index]).append(view.getActionBar())

      # adds the class name to the icon
      $(ui.tab).find('.icon').addClass(view.className)
      # renders the corresponding view inside the tab and displays it
      $(ui.panel).append(view.render().$el)
      @_tabs.select(@_indexOfView id)

    # **private**
    # trigger the tab close procedure when clicking on the relevant icon.
    #
    # @param event [Event] click event on the close icon
    _onCloseTab: (event) =>
      event.preventDefault()
      id = $(event.target).closest('a').attr('href').replace('#tabs-', '')
      idx = @_indexOfView(id)
      return unless idx isnt -1
      console.log("try to close tab for view #{@_views[idx].getTitle()}")
      @tryCloseTab(@_views[idx])

    # **private**
    # Save hotkey handler. Try to save current tab.
    #
    # @param event [Event] keyboard event
    _onSaveHotKey: (event) =>
      event?.preventDefault()
      # tries to save current
      return false unless @_tabs?.options.selected isnt -1
      console.log("save current tab ##{@_tabs.options.selected} by hotkey")
      @_views[@_tabs.options.selected].saveModel()
      return false

    # **private**
    # Remove hotkey handler. Try to save current tab.
    #
    # @param event [Event] keyboard event
    _onRemoveHotKey: (event) =>
      event?.preventDefault()
      # tries to save current
      return false unless @_tabs?.options.selected isnt -1
      console.log("remove current tab ##{@_tabs.options.selected} by hotkey")
      @_views[@_tabs.options.selected].removeModel()
      return false

    # **private**
    # Close hotkey handler. Try to save current tab.
    #
    # @param event [Event] keyboard event
    _onCloseHotKey: (event) =>
      event?.preventDefault()
      # tries to save current
      return false unless @_tabs?.options.selected isnt -1
      console.log("close current tab ##{@_tabs.options.selected} by hotkey")
      @tryCloseTab(@_views[@_tabs.options.selected])
      return false

  return EditionPerspective