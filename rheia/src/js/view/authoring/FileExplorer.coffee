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
  'backbone'
  'i18n!nls/common'
  'i18n!nls/authoring'
  'model/FSItem'
], ($, Backbone, i18n, i18nAuthoring, FSItem) ->

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
    name = item.get('path').substring item.get('path').lastIndexOf('\\')+1
    if item.get 'isFolder'
      html = """
        <div class="folder" data-path="#{item.get('path')}">
          <h1><i></i>#{name}</h1>
          <div class="content"></div>
        </div>
      """
    else 
      html = """<div data-path="#{item.get('path')}" class="file #{item.extension}"><i></i>#{name}</div>"""
    html

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

    # **private**
    # Current selected path
    _selected: null

    # **private**
    # Previously selected path
    _previousSelected: null

    # The view constructor.
    constructor:  ->
      super tagName: 'div', className:"file explorer"

      # bind to global events
      @bindTo FSItem.collection, 'update', @_onUpdate

    # The `render()` method is invoked by backbne to display view content at screen.
    # oInstanciate bar buttons.
    render: =>
      super()

      # load root content
      FSItem.collection.fetch()

      # for chaining purposes
      @

    # **private**
    # Handler invoked when a new FSItem was updated
    # If folder, displayed its content inside explorer
    # 
    # @param item [FSItem] the updated FSItem
    _onUpdate: (item) =>
      return unless item.get 'isFolder'
      parentNode = @$el
      path = item.get 'path'
      animate = false

      if path.length
        # Get the existing folder inside explorer
        parentNode = @$el.find "div[data-path='#{path.replace(/\\/g, '\\\\')}'] > .content"
        animate = true

      content = item.get 'content'
      # sort content: first folder, then item
      content.sort comparator

      # redraw all content inside parent.
      parentNode.empty()
      parentNode.append renderItem subItem for subItem in content
      # animate the container unless root
      parentNode.show().css(x:-animShift).transition x:0, animDuration if animate

    # **private**
    # Click handler in file explorer: de/select right node and trigger event.
    #
    # @param event [Event] click event inside folder
    _onSelect: (event) =>
      node = $(event.target).closest 'div'
      path = node.data 'path'
      return unless path?
      
      # keep previous selected and remove class
      @_previousSelected = @$el.find('.selected').data 'path'
      @$el.find('.selected').removeClass 'selected'

      # select new one unless it's same node
      unless path is @_previousSelected
        @_selected = path
        node.addClass 'selected'
      else
        @_selected = null

      # open or close folder if possible
      if node.hasClass 'folder'
        container = node.find '> .content'
        unless node.hasClass 'open'
          container.show().css(x:-animShift).transition x:0, animDuration
        else
          container.transition x:-animShift, animDuration, -> container.hide()
        node.toggleClass 'open'

      # trigger an event
      @trigger 'select', @_selected, @_previousSelected
      
    # **private**
    # When clicking on a closed folder, load its content
    # 
    # @param event [Event] click event on a closed folder
    _onLoad: (event) =>
      node = $(event.target).closest 'div'
      @_onSelect event
      node.addClass 'loaded open'
      # Load the folder's content
      FSItem.collection.fetch
        item: new FSItem
          path: node.data 'path'
          isFolder: true