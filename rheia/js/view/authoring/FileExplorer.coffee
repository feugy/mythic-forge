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
  'underscore'
  'backbone'
  'i18n!nls/common'
  'i18n!nls/authoring'
  'model/FSItem'
  'widget/toggleable'
], ($, _, Backbone, i18n, i18nAuthoring, FSItem) ->

  i18n = $.extend true, i18n, i18nAuthoring

  # animation duration and size
  animDuration= 200
  animShift= 250

  # Creates rendering for a given FSItem
  #
  # @param item [FSItem] the rendered item
  # @return the corresponding rendering
  renderItem = (item) ->
    html = ''
    name = item.get('path').substring item.get('path').lastIndexOf(conf.separator)+1
    if item.get 'isFolder'
      html = """
        <div class="folder" data-path="#{item.get 'path' }">
          <h1><i></i>#{name}</h1>
          <div class="content"></div>
        </div>
      """
    else 
      html = """<div data-path="#{item.get 'path'}" class="file #{item.extension}"><i></i>#{name}</div>"""
    $(html)

  # Comparator function, that allows to sort FSItems inside the collection.
  # First, folders, then files. Both alphabetically sorted
  #
  # @param item1 [FSItem] the first compared FSItem
  # @param item2 [FSItem] the second compared FSItem
  # @return -1 if the first FSItem should come before the second, 0 if they 
  # are of the same rank and 1 if the first FSItem should come after. 
  comparator = (item1, item2) =>
    if item1.get 'isFolder'
      # item2 is file, item1 is folder
      return -1 unless item2.get 'isFolder'
    else 
      # item1 is file, item2 is folder
      return 1 if item2.get 'isFolder'
    # same nature: compare path
    path1 = item1.get('path').toLowerCase()
    path2 = item2.get('path').toLowerCase()
    if path1 < path2 then -1 else if path1 > path2 then 1 else 0

  # The FileExplorer view allow to navigate within folders and files of the game client.
  class FileExplorer extends Backbone.View
    
    # rendering event mapping
    events: 
      'click .folder:not(.loaded) > h1': '_onLoad'
      'click .folder.loaded > h1': '_onSelect'
      'click .file': '_onSelect'
      'click .menu .open': '_onSelect'
      'click .menu .remove': '_onMenuRemove'
      'click .menu .rename': '_onMenuRename'
      'click .menu .new': '_onMenuCreate'
      'contextmenu': '_onShowMenu'

    # Current selected path
    selected: null

    # **private**
    # Previously selected path
    _previousSelected: null

    # **private**
    # Loading flag to ignore fsItem addition
    _loading: false

    # **private**
    # Contextual menu
    _menu: null

    # The view constructor.
    constructor:  ->
      super tagName: 'div', className:"file explorer"

      # bind to global events
      @bindTo FSItem.collection, 'reset', @_onReset
      @bindTo FSItem.collection, 'update', @_onUpdate
      @bindTo FSItem.collection, 'add', @_onAdd
      @bindTo FSItem.collection, 'remove', @_onRemove

    # The `render()` method is invoked by backbne to display view content at screen.
    # oInstanciate bar buttons.
    render: =>
      super()

      # load root content
      FSItem.collection.fetch()

      # adds a contextual menu that opens on right click
      @_menu = $("""<ul class="menu"></ul>""").toggleable().appendTo(@$el).data 'toggleable'

      # for chaining purposes
      @
      
    # **private**
    # Fills and displays contextual menu
    #
    # @param collection [FSItem.collection] the list of root FSItem
    _onShowMenu: (event) =>
      event?.preventDefault()
      event?.stopImmediatePropagation()
      item = FSItem.collection.get $(event.target).closest('.file,.folder').data 'path'
      return unless item?
      path = item.get 'path'
      name = path.substring path.lastIndexOf(conf.separator)+1

      # keep previous selected and remove class
      @_previousSelected = @$el.find('.selected').data 'path'
      @$el.find('.selected').removeClass 'selected'
      @selected = path
      node = $(event.target).closest('div, ul').addClass 'selected'

      folder = item.get 'isFolder'
      @_menu.$el.empty().data('folder', folder).data 'path', path
      if folder
        content = """
          <li class='new new-file'><i class='x-small ui-icon new-file'></i>#{i18n.labels.newFile}</li>
          <li class='new new-folder'><i class='x-small ui-icon new-folder'></i>#{i18n.labels.newFolder}</li>
        """
      else
        content = "<li class='open'><i class='x-small ui-icon open'></i>#{_.sprintf i18n.labels.openFSItem, name}</li>"
      content += """
        <li class='rename'><i class='x-small ui-icon rename'></i>#{_.sprintf i18n.labels.renameFSItem, name}</li>
        <li class='remove'><i class='x-small ui-icon remove'></i>#{_.sprintf i18n.labels.removeFSItem, name}</li>
      """
      @_menu.$el.append content
      @_menu.open event?.pageX, event?.pageY

    # **private**
    # Handler invoked when the root content have been retrieved
    #
    # @param collection [FSItem.collection] the list of root FSItem
    _onReset: (collection) =>
      # sort content: first folder, then item
      collection.models.sort comparator

      # redraw all content inside parent.
      @$el.empty()
      @$el.append renderItem subItem for subItem in collection.models
      @$el.append @_menu.$el

    # **private**
    # New item added handler: update the tree if this item should appear
    #
    # @param item [FSItem] added item
    _onAdd: (item) =>
      # ignore restored items
      return if @_loading or item.restored
      # do not add if already present (escape \. Leave / as existing)
      existing = @$el.find "div[data-path='#{item.get('path').replace(/\\/g, '\\\\')}']"
      return unless existing.length is 0

      # evaluate the parent
      parentPath = item.get('path').substring 0, item.get('path').lastIndexOf conf.separator
      if parentPath is ''
        # under the root
        parentNode = @$el
        content = _.map(@$el.children(), (node) -> FSItem.collection.get $(node).data 'path').concat()

      else
        # under a folder
        parent = FSItem.collection.get parentPath
        return unless parent? and parent.get('content')?
        # escape \. Leave / as existing
        parentNode = @$el.find "div[data-path='#{parentPath.replace(/\\/g, '\\\\')}'] > .content"
        content = parent.get('content').concat()

      # evaluate insertion order
      content.push item
      content.sort comparator
      idx = content.indexOf item

      # appends the new node
      render = renderItem item
      if idx is parentNode.children().length
        parentNode.append render
      else
        parentNode.children().eq(idx).before render
      render.css(x:-animShift).transition x:0, animDuration

    # **private**
    # Existing item removal handler: update the tree if this item is present appear
    #
    # @param item [FSItem] removed item
    _onRemove: (item) =>
      # escape \. Leave / as existing
      removed = @$el.find "div[data-path='#{item.get('path').replace(/\\/g, '\\\\')}']"
      pos = removed.offset()

      # remove immediately from parent to allow renaming
      $('body').append removed
      removed.css 
        position: 'absolute'
        top: pos.top
        left: pos.left
      
      removed.transition 
        x:-animShift, 
        animDuration, 
        =>
          removed.remove()
          # update selected state
          if @selected is item.id
            @_previousSelected = null
            @selected = null
            @trigger 'select', @selected, @_previousSelected

    # **private**
    # Handler invoked when a new FSItem was updated
    # If folder, displayed its content inside explorer
    # 
    # @param item [FSItem] the updated FSItem
    _onUpdate: (item) =>
      # for files, use _onAdd
      return @_onAdd item unless item.get 'isFolder'
      @_loading = false
      # Get the existing folder inside explorer
      path = item.get 'path'
      # escape \. Leave / as existing
      parentNode = @$el.find "div[data-path='#{path.replace(/\\/g, '\\\\')}'] > .content"

      content = item.get 'content'
      # sort content: first folder, then item
      content.sort comparator

      # redraw all content inside parent.
      parentNode.empty()
      parentNode.append renderItem subItem for subItem in content
      # animate the container unless root
      parentNode.show().css(x:-animShift).transition x:0, animDuration

    # **private**
    # Click handler in file explorer: de/select right node and trigger event.
    #
    # @param event [Event] click event inside folder
    _onSelect: (event) =>
      node = $(event.target).closest 'div, ul'
      path = node.data 'path'
      return unless path?
      
      # keep previous selected and remove class
      @_previousSelected = @$el.find('.selected').data 'path'
      @$el.find('.selected').removeClass 'selected'

      # select new one unless it's same node
      unless path is @_previousSelected
        @selected = path
        node.addClass 'selected'
      else
        @selected = null

      # open or close folder if possible
      if node.hasClass 'folder'
        container = node.find '> .content'
        # Only close when folder
        unless node.hasClass 'open'
          container.show().css(x:-animShift).transition x:0, animDuration, -> $(this).css transform: ''
        else
          container.transition x:-animShift, animDuration, -> 
            $(this).css transform: ''
            $(this).hide()
        node.toggleClass 'open'

      # trigger an event
      @trigger 'select', @selected, @_previousSelected
      
    # **private**
    # When clicking on a closed folder, load its content
    # 
    # @param event [Event] click event on a closed folder
    _onLoad: (event) =>
      node = $(event.target).closest 'div'
      @_onSelect event
      node.addClass 'loaded open'
      @_loading = true
      # Load the folder's content
      FSItem.collection.fetch
        item: new FSItem
          path: node.data 'path'
          isFolder: true

    # **private**
    # Handler of contextual menu remove item. Triggers `remove` event.
    # 
    # @param event [Event] click event insed contextual menu
    _onMenuRemove: (event) =>
      node = $(event.target).closest 'ul'
      path = node.data 'path'
      isFolder = node.data 'folder'
      return unless path? and isFolder?
      # trigger an event
      @trigger 'remove', path, isFolder

    # **private**
    # Handler of contextual menu rename item. Triggers `rename` event.
    # 
    # @param event [Event] click event insed contextual menu
    _onMenuRename: (event) =>
      node = $(event.target).closest 'ul'
      path = node.data 'path'
      isFolder = node.data 'folder'
      return unless path? and isFolder?
      # trigger an event
      @trigger 'rename', path, isFolder, path

    # **private**
    # Handler of contextual menu create items. Triggers `create` event.
    # 
    # @param event [Event] click event insed contextual menu
    _onMenuCreate: (event) =>
      node = $(event.target).closest 'ul'
      path = node.data 'path'
      isFolder = $(event.target).closest('li').hasClass 'new-folder'
      return unless path? and isFolder?
      # trigger an event
      @trigger 'create', path, isFolder