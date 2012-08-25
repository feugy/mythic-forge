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
  'widget/advEditor'
], ($, _, Backbone, i18n, i18nAuthoring) ->

  i18n = $.extend(true, i18n, i18nAuthoring)

  # View that allows to edit files
  class FileView extends Backbone.View

    # the edited FSItem
    file: null    

    # **private**
    # widget that allows content edition
    _editorWidget: null

    # The view constructor.
    #
    # @param file [FSItem] the edited object.
    constructor: (@file) ->
      super tagName: 'div', className:"file view"
     
      @_canSave = false

    # Returns a unique id. 
    #
    # @return If the edited object is persisted on server, return its id. Otherwise, a temporary unic id.
    getId: =>
      @file.path

    # Returns the view's title
    #
    # @return the edited object name.
    getTitle:  =>
      @file.path.substring @file.path.lastIndexOf('\\')+1

    # The `render()` method is invoked by backbone to display view content at screen.
    render: =>
      # template rendering
      super()

      # instanciate the content editor
      @_editorWidget = $('<div class="content"></div>').advEditor(
        #change: @_onChange
        #mode: 'coffee'
      ).data 'advEditor'
      @$el.empty().append @_editorWidget.element

      # for chaining purposes
      return @

    # Method invoked when the view must be closed.
    # @return true if the view can be closed, false to cancel closure
    canClose: =>
      return true