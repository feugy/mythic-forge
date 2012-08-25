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
  'view/TabPerspective'
  'i18n!nls/common'
  'i18n!nls/authoring'
  'text!tpl/authoringPerspective.html'
  'view/authoring/FileExplorer'
  'view/authoring/File'
], ($, _, Backbone, TabPerspective, i18n, i18nAuthoring, template, FileExplorer, FileView) ->

  i18n = $.extend true, i18n, i18nAuthoring

  # The authoring perspective allows to manage game client files
  class AuthoringPerspective extends TabPerspective
    
    # rendering event mapping
    # events: 

    # **private**
    # View's mustache template
    _template: template

    # **private**
    # Explorer view
    _explorer: null

    # **private**
    # Button to create new files inside selected folder
    _newFileButton: null

    # **private**
    # Button to create new folder inside selected folder
    _newFolderButton: null

    # **private**
    # Button to upload files inside selected folder
    _uploadButton: null

    # **private**
    # Button to save edited file
    _saveButton: null

    # **private**
    # Button to remove edited file
    _removeButton: null

    # **private**
    # Button to rename selected file/folder
    _renameButton: null

    # The view constructor.
    constructor: ->
      super 'authoring'

      # construct explorer
      @_explorer = new FileExplorer()
      @bindTo @_explorer, 'select', @_onSelect

    # The `render()` method is invoked by backbne to display view content at screen.
    # oInstanciate bar buttons.
    render: =>
      super()

      # render the explorer on the left
      @$el.find('> .left').append @_explorer.render().$el

      # build buttons.
      buttons = [
        icon: 'new-file'
        handler: (event) => 
          event?.preventDefault()
          @_onOpenElement null
        attribute: '_newFileButton'
      ,
        icon: 'new-folder'
        handler: null
        attribute: '_newFolderButton'
      ]
      for spec in buttons
        @[spec.attribute] = @$el.find(".action-bar .#{spec.icon}").button(
          icons:
            primary: "small #{spec.icon}"
          text: false
        ).click(spec.handler).data 'button'

      # for chaining purposes
      return @

    # **private**
    # Provide template data for rendering
    #
    # @return an object used as template data
    _getRenderData: =>
      i18n:i18n

    # **private**
    # Delegate method the instanciate a view from a type and an id, either
    # when opening an existing view, or when creating a new one.
    #
    # @param type [String] type of the opened/created instance
    # @param id [String] optional id of the opened instance. Null for creations
    # @return the created view, or null to cancel opening/creation
    _constructView: (type, id) =>
      view = null
      unless type?
        view = new FileView 
          path: 'test.txt'
          isFolder: false
          content: 'coucou !'
      return view

    # **private**
    # Selection handler inside the file explorer.
    # If a file is selected, opens it.
    # Whatever was selected, update the button bar conséquently
    #
    # @param selected [String] path of the currently selected fsitem. May be null
    # @param previous [String] path of the previously selected fsitem. May be null
    _onSelect: (selected, previous) =>
      console.dir arguments