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
  'model/FSItem'
  'view/authoring/FileExplorer'
  'view/authoring/File'
  'utils/utilities'
  'utils/validators'
], ($, _, Backbone, TabPerspective, i18n, i18nAuthoring, template, FSItem, FileExplorer, FileView, utils, validators) ->

  i18n = $.extend true, i18n, i18nAuthoring

  # The authoring perspective allows to manage game client files
  class AuthoringPerspective extends TabPerspective

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
    # Button to rename selected file/folder
    _renameButton: null

    # **private**
    # Button to remove selected folder
    _removeFolderButton: null

    # **private**
    # Button to save edited file
    _saveButton: null

    # **private**
    # Button to remove edited file
    _removeButton: null

    # **private**
    # FSItem created to catch server error while creating
    _createInProgress: null

    # The view constructor.
    constructor: ->
      super 'authoring'

      # construct explorer
      @_explorer = new FileExplorer()
      @bindTo @_explorer, 'select', @_onSelect
      @bindTo rheia.router, 'serverError', @_onServerError
      @bindTo FSItem.collection, 'add', @_onItemCreated

    # The `render()` method is invoked by backbne to display view content at screen.
    # oInstanciate bar buttons.
    render: =>
      super()
      # update button bar on tab change, but after a slight delay to allow internal update when 
      # tab is removed
      @_tabs.element.on 'tabsselect', => setTimeout (=> @_onFileChange()), 0

      # render the explorer on the left
      @$el.find('> .left').append @_explorer.render().$el

      # build buttons.
      buttons = [
        icon: 'new-folder'
        tip: i18n.tips.newFolder
        handler: => @_onNewItem true
        attribute: '_newFileButton'
      ,
        icon: 'new-file'
        tip: i18n.tips.newFile
        handler: => @_onNewItem false
        attribute: '_newFolderButton'
      ,
        icon: 'upload'
        tip: i18n.tips.uploadInSelected
        attribute: '_uploadButton'
      ,
        icon: 'rename'
        tip: i18n.tips.renameSelected
        attribute: '_renameButton'
      ,
        icon: 'remove-folder'
        tip: i18n.tips.removeFolder
        handler: @_onRemoveFolder
        attribute: '_removeFolderButton'
      ,
        icon: 'save'
        tip: i18n.tips.saveFile
        handler: @_onSaveHotKey
        attribute: '_saveButton'
      ,
        icon: 'remove'
        tip: i18n.tips.removeFile
        handler: @_onRemoveHotKey
        attribute: '_removeButton'
      ]
      for spec in buttons
        @[spec.attribute] = @$el.find(".action-bar .#{spec.icon}").button(
          icons:
            primary: "small #{spec.icon}"
          text: false
          disabled: true
        ).attr('title', spec.tip).click(spec.handler).data 'button'

      # first selection
      @_onSelect null, null

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
    # @param type [String] type of the opened/created instance. Must be null.
    # @param id [String] optional id of the opened instance. Null for creations
    # @return the created view, or null to cancel opening/creation
    _constructView: (type, id) =>
      return null if type?
      new FileView id

    # **private**
    # Creates a new FSItem with the given name into the selected fodler.
    #
    # @param name [String] name of the desired item
    # @param isFolder [Boolean] true to create a folder, false to create a file
    _createItem: (name, isFolder) =>
      root = if @_explorer.selected? then "#{@_explorer.selected}#{conf.separator}" else ''
      @_createInProgress = new FSItem path: "#{root}#{name}", isFolder: isFolder, content: null
      
      # check first of non-existence
      return @_onServerError 'File already exists' if FSItem.collection.get(@_createInProgress.id)?

      # otherwise, save it
      @_createInProgress.save()

    # **private**
    # Callback invoked when an item has been created on server.
    # If creation in progress and file, opens it.
    #
    # @param className [String] the modified object className
    # @param model [Object] created model.
    _onItemCreated: (created) =>
      return unless @_createInProgress?.equals created
      @_createInProgress = null
      @_onOpenElement null, created.id unless created.get 'isFolder'

    # **private**
    # Server error handler: display errors while creating new folder and files
    _onServerError: (err, details) =>
      return unless @_createInProgress?
      title = i18n.titles[if @_createInProgress.isFolder then 'newFolder' else 'newFile']
      utils.popup title, _.sprintf(i18n.msgs.fsItemCreationFailed, @_createInProgress.get('path'), err), 'warning', [
        text: i18n.labels.ok
        icon: 'valid'
      ]
      @_createInProgress = null

    # **private**
    # Handler invoked when a tab was added to the widget. Render the view inside the tab.
    #
    # @param event [Event] tab additon event
    # @param ui [Object] tab container 
    _onTabAdded: (event, ui) =>
      # calls inherited method
      super event, ui
      # gets the added view from the internal array
      id = $(ui.tab).attr('href').replace '#tabs-', ''
      view = _.find @_views, (view) -> id is md5 view.getId()
      
      # bind changes to update tab
      view.on 'change', @_onFileChange

    # **private**
    # Item creation handler: prompt for name, creates the FSItem, and opens it if it's a file
    #
    # @param isFolder [Boolean] distinguish the creation of a folder and a file
    _onNewItem: (isFolder) =>
      selected = @_explorer.selected
      # displays the popup
      popup = utils.popup(i18n.titles[if isFolder then 'newFolder' else 'newFile'],
        _.sprintf(i18n.msgs[if isFolder then 'newFolder' else 'newFile'], if selected? then selected else i18n.labels.rootFolder),
        'question',
        [
          text: i18n.labels.create
          icon: 'valid'
          click: =>
            # Do not proceed unless no validation error
            validator.validate()
            return false unless validator.errors.length is 0
            validator.dispose()
            # trim value and creates fsItem
            @_createItem popup.find('input.name').val().trim(), isFolder
        ,
          text: i18n.labels.cancel
          icon: 'cancel'
          click: => validator.dispose()
        ],
        1).addClass 'name-choose-popup'

      # adds a text field and an error field above it
      input = $('<input type="text" class="name"/>').appendTo popup
      popup.append "<div class='errors'></div>"

      # creates the validator
      validator = new validators.Regexp 
        required: true, 
        spacesAllowed: true, 
        # must contains LATIN-1 visible characters except / and \. Can also contain accentuated LATIN-1 supplement.
        # http://fr.wikipedia.org/wiki/Table_des_caract%C3%A8res_Unicode_%280000-0FFF%29
        regexp: /^[\u0020-\u002E\u0030-\u005B\u005D-\u007E\u00C0-\u00FF]+$/
      , i18n.labels.fsItemName, input, 'keyup' 

      # displays error on keyup. Binds after validator creation to validate first
      input.on 'keyup', =>
        # displays error on keyup
        popup.find('.errors').empty()
        if validator.errors.length
          popup.find('.errors').append error.msg for error in validator.errors
    
    # **private**
    # Handler that removes selected fsItem after a confirmation popup
    _onRemoveFolder: =>
      # get selected item
      removed = FSItem.collection.get @_explorer.selected
      return unless removed? and removed.get 'isFolder'
      #confirmation popup
      utils.popup i18n.titles.removeConfirm, 
        _.sprintf(i18n.msgs.removeFolderConfirm, removed.get 'path'), 
        'question', [
          text: i18n.labels.no
          icon: 'invalid'
        ,
          text: i18n.labels.yes
          icon: 'valid'
          click: => removed.destroy()
        ]

    # **private**
    # Current edited file change handler: updates the button bar consequently
    _onFileChange: =>
      @_saveButton._setOption 'disabled', true
      @_removeButton._setOption 'disabled', true
      if @_tabs.options.selected isnt -1
        view = @_views[@_tabs.options.selected]
        @_saveButton._setOption 'disabled', !view.canSave()
        @_removeButton._setOption 'disabled', !view.canRemove()

    # **private**
    # Selection handler inside the file explorer.
    # If a file is selected, opens it.
    # Whatever was selected, updates the button bar consequently
    #
    # @param selected [String] path of the currently selected fsitem. May be null
    # @param previous [String] path of the previously selected fsitem. May be null
    _onSelect: (selected, previous) =>
      fileSelected = false
      selectedItem = null
      if selected?
        # get the selected FSItem
        selectedItem = FSItem.collection.get selected
        throw new Error "Unknown fsItem selected #{selected}" unless selectedItem?
        # Open the relevant file view
        unless selectedItem.get 'isFolder'
          @_onOpenElement null, selectedItem.id
          fileSelected = true

      # update button bar
      @_newFolderButton._setOption 'disabled', fileSelected
      @_newFileButton._setOption 'disabled', fileSelected
      @_uploadButton._setOption 'disabled', true # fileSelected
      @_renameButton._setOption 'disabled', true # selected is null
      @_removeFolderButton._setOption 'disabled', selectedItem is null or ! selectedItem.get 'isFolder'
      @_onFileChange()