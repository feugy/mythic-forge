###
  Copyright 2010~2014 Damien Feugas
  
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
  'i18n!nls/common'
  'jquery'
  'underscore'
  'backbone'
], (i18n, $, _, Backbone) ->

  # Abstract View class that embed common behaviour of perspectives.
  # Manage tab widget, shortcuts view opening and closing.
  # If no action bar is found inside template, the corresponding widget
  # will not be created, and this does not prevent others to work properly.
  #
  # `_getRenderData()`, `_constructView()` methods must be implemented.
  # `_template` attribute must be set.
  class TabPerspective extends Backbone.View
    
    # **private**
    # views displayed into the tab container.
    _views: []

    # **private**
    # the tab widget containing views.
    _tabs: null

    # **private**
    # special tab widget containing actions bars
    # this widget is totally optionnal
    _actionBars: null

    # **private**
    # bypass the close confirmation when closing a view. Used when object was removed.
    _forceClose: false
   
    # The view constructor.
    #
    # @param className [String] css ClassName, set by subclasses
    constructor: (@className) ->
      super tagName: 'div', className:"#{@className} perspective"

      @_views = []
      @_tabs = null
      @_actionBars = null
      @_forceClose = false

      # bind to global events
      @bindTo app.router, 'open', @_onOpenElement
      @bindTo app.router, 'remove', @_onRemoveElement

      # bind shortcuts
      $(document).on("keydown.#{@cid}", {keys:'ctrl+s', includeInputs:true}, @_onSaveHotKey)
        .on("keydown.#{@cid}", {keys:'ctrl+shift+d', includeInputs:true}, @_onRemoveHotKey)
        .on "keydown.#{@cid}", {keys:'ctrl+q', includeInputs:true}, @_onCloseHotKey

      # bind unload warning
      $(window).on 'beforeunload.#{@cid}', (event) =>
        # check that all view were saved
        return unless _.find(@_views, (v) -> v.canSave())?
        event.returnValue = _.sprintf i18n.msgs.confirmUnload, i18n.titles["#{className}Perspective"]

    # The view destroyer: unbinds shortcuts
    dispose: =>
      # removes shortcuts
      $(document).unbind ".#{@cid}"
      $(window).unbind ".#{@cid}"
      super()

    # The `render()` method is invoked by backbone to display view content at screen.
    # Instanciate tab widget for view and optional action bar
    render: =>
      super()
      # instanciates a tab widget for views
      @_tabs = @$el.find('> .right .ui-tabs.views').tabs(
          # template with close button
          tabTemplate: """ <li>
              <a href="\#{href}">
                <i class="icon"></i>
                <span class="content">\#{label}</span>
                <i class="ui-icon ui-icon-close"></i>
              </a>
            </li> """
        )
        # handlers
        .bind('tabsadd', @_onTabAdded)
        .bind('tabsselect', (event, ui) => 
          # avoid updating window location
          event?.stopPropagation()
          @_actionBars?.select ui.index
          @_views[ui.index]?.shown()
        ).data 'tabs'

      # instanciates a tab widget for action bars
      @_actionBars = @$el.find('> .right .ui-tabs.action-bars').tabs().data 'tabs'

      # for chaining purposes
      @

    # invoked when perspective is shown: relay event to displayed tab
    shown: =>
      @_views?[@_tabs.options.selected]?.shown()

    # tries to close a tab, if the corresponding views allowed it.
    #
    # @param view [Object] the corresponding view
    tryCloseTab: (view) =>
      # if closure is allowed, removes the tab
      if @_forceClose or view.canClose()
        @_forceClose = false
        idx = @_indexOfView view.model.id
        return if idx is -1
        console.log "view #{view.getTitle()} closure"
        @_views.splice idx, 1
        removed = @_tabs?.remove idx
        $(removed).find('.ui-icon-close').off()
        @_actionBars?.remove idx
        view.off 'change'
      else
        console.log "view #{view.getTitle()} cancels its closure"

    # **private**
    # Delegate method the instanciate a view from a type and an id, either
    # when opening an existing view, or when creating a new one.
    # This methods throws an 'unimplemented method' exception.
    #
    # @param type [String] type of the opened/created instance
    # @param id [String] optional id of the opened instance. Null for creations
    # @param args [Array] optional arguments for view creation
    # @return the created view, or null to cancel opening/creation
    _constructView: (type, id, args) =>
      throw new Error '_constructView() must be implemented by subclasses'

    # **private**
    # Finds the position of a view inside the `_views` array, with its id.
    #
    # @param id [String] the searched view's id.
    # @return index of the corresponding view, of -1
    _indexOfView: (id) =>
      idx = (i for view, i in @_views when view.model.id is id)
      if idx.length is 1 then idx[0] else -1

    # **private**
    # Get the id of a given view that can be used inside the DOM as an Id or a class.
    # 
    # @param view [Object] the concerned view
    # @return its DOM compliant id
    _domId: (view) => view.model.id

    # **private**
    # This method is invoked when an element must be showned in a tab.
    #  
    # @param type [String] opened element className.
    # @param id [String] opened element id, or null for a creation.
    # @param args... [Any] optional creation arguments
    _onOpenElement: (type, id, args...) =>
      # first check if the view is not already opened.
      if id?
        idx = @_indexOfView id
        return @_tabs.select idx unless idx is -1

      # creates the relevant view
      view = @_constructView type, id, args
      return unless view?

      @_views.push view
      @_tabs.add "#tabs-#{@_domId view}", view.getTitle()

    # **private**
    # This method is invoked when an element must be removed.
    #  
    # @param type [String] opened element className.
    # @param id [String] opened element id, or null for a creation.
    _onRemoveElement: (type, id) =>
      # first check if the view is not already opened.
      if id?
        idx = @_indexOfView id
        return @_views[idx].removeModel() unless idx is -1

      # constructs a temporary view to immediatly removes its model (only if construcView supports it)
      view = @_constructView type, id
      view?.removeModel()
      # don't forget to dispose view, or some events will be processed multiple times !
      view?.dispose()

    # **private**
    # Handler invoked when a tab was added to the widget. Render the view inside the tab.
    #
    # @param event [Event] tab additon event
    # @param ui [Object] tab container 
    _onTabAdded: (event, ui) =>
      # gets the added view from the internal array
      domId = $(ui.tab).attr('href').replace '#tabs-', ''
      view = _.find @_views, (view) => domId is @_domId view
      # bind close behaviour
      $(ui.tab).find('.ui-icon-close').on 'click', @_onCloseTab
      
      # bind changes to update tab
      view.on 'change', () =>
        tab = @_tabs.element.find "a[href=#tabs-#{@_domId view}] .content"
        # toggle Css class modified wether we can save the view
        tab.toggleClass 'modified', view.canSave()
        # adds the class name to the icon
        tab.prev('.icon').attr 'class', "icon #{view.className}"
        # updates title
        tab.html view.getTitle()

      # bind close we view ask for it
      view.on 'close', => @tryCloseTab view
      $(ui.tab).find('.icon').attr 'class', "icon #{view.className}"

      # adds the action bar to the other ones
      @_actionBars?.add "#actionBar-#{@_domId view}", view.model.id, ui.index
      if @_actionBars?
        $(@_actionBars.panels[ui.index]).append view.getActionBar()

      # renders the corresponding view inside the tab and displays it
      $(ui.panel).append view.render().$el
      @_tabs.select @_views.indexOf view

    # **private**
    # trigger the tab close procedure when clicking on the relevant icon.
    #
    # @param event [Event] cancelled click event on the close icon
    _onCloseTab: (event) =>
      event?.preventDefault()
      domId = $(event.target).closest('a').attr('href').replace '#tabs-', ''
      view = _.find @_views, (view) => domId is @_domId view
      return unless view?
      console.log "try to close tab for view #{view.getTitle()}"
      @tryCloseTab view

    # **private**
    # Save hotkey handler. Try to save current tab.
    #
    # @param event [Event] keyboard event
    _onSaveHotKey: (event) =>
      return unless @$el.is ':visible'
      event?.preventDefault()
      event?.stopImmediatePropagation()
      # tries to save current
      return false unless @_tabs?.options.selected isnt -1
      console.log "#{@className} save current tab ##{@_tabs.options.selected} by hotkey"
      @_views[@_tabs.options.selected]?.saveModel()
      false

    # **private**
    # Remove hotkey handler. Try to save current tab.
    #
    # @param event [Event] keyboard event
    _onRemoveHotKey: (event) =>
      return unless @$el.is ':visible'
      event?.preventDefault()
      event?.stopImmediatePropagation()
      # tries to save current
      return false unless @_tabs?.options.selected isnt -1
      console.log "#{@className} remove current tab ##{@_tabs.options.selected} by hotkey"
      @_views[@_tabs.options.selected]?.removeModel()
      false

    # **private**
    # Close hotkey handler. Try to save current tab.
    #
    # @param event [Event] keyboard event
    _onCloseHotKey: (event) =>
      return unless @$el.is ':visible'
      event?.preventDefault()
      event?.stopImmediatePropagation()
      # tries to save current
      return false unless @_tabs?.options.selected isnt -1
      console.log "#{@className} close current tab ##{@_tabs.options.selected} by hotkey"
      @tryCloseTab @_views[@_tabs.options.selected] if @_views[@_tabs.options.selected]?
      false