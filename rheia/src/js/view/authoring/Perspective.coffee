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
      @_tabs.element.on 'tabsselect', => setTimeout (=> @_onUpdateFileBar()), 0

      # render the explorer on the left
      @$el.find('> .left').append @_explorer.render().$el

      # build buttons.
      buttons = [
        icon: 'new-folder'
        tip: i18n.tips.newFolder
        handler: => @_chooseFileName true
        attribute: '_newFileButton'
      ,
        icon: 'new-file'
        tip: i18n.tips.newFile
        handler: => @_chooseFileName false
        attribute: '_newFolderButton'
      ,
        icon: 'upload'
        tip: i18n.tips.uploadInSelected
        handler: => @$el.find('.file-upload > input').trigger 'click'
        attribute: '_uploadButton'
      ,
        icon: 'rename'
        tip: i18n.tips.renameSelected
        handler: => 
          selected = FSItem.collection.get @_explorer.selected
          return unless selected?
          @_chooseFileName selected.get('isFolder'), @_explorer.selected
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

      # bind file upload
      @$el.find('.file-upload > input').on 'change', @_onFileChoosen

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
    # Creates or move a FSItem with the given name into the selected fodler.
    #
    # @param name [String] name of the desired item
    # @param isFolder [Boolean] true to create a folder, false to create a file
    # @param oldName [Sting] old name in case of a renaming
    _createMoveItem: (name, isFolder, oldName=null) =>
      root = if @_explorer.selected? then "#{@_explorer.selected}#{conf.separator}" else ''
      newName = "#{root}#{name}"
      if oldName?
        parent = oldName.substring 0, oldName.lastIndexOf conf.separator
        newName = "#{if parent isnt '' then "#{parent}#{conf.separator}" else ''}#{name}"

      @_createInProgress = new FSItem path: (if oldName? then oldName else newName), isFolder: isFolder, content: null
      
      # check first of non-existence
      return @_onServerError 'File already exists' if FSItem.collection.get(newName)?

      if oldName?
        @_createInProgress.move(newName)
      else
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
        text: i18n.buttons.ok
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
      view.on 'change', @_onUpdateFileBar

    # **private**
    # Item creation/move handler: prompt for name, creates the FSItem and opens it if it's a file, or moves the FSItem
    #
    # @param isFolder [Boolean] distinguish the creation of a folder and a file
    # @parma oldName [String] old name of the renamed item. Default to null
    _chooseFileName: (isFolder, oldName = null) =>
      selected = @_explorer.selected
      title = if oldName? then i18n.titles.renameFSItem else i18n.titles[if isFolder then 'newFolder' else 'newFile']
      if oldName?
        msg = i18n.msgs[if isFolder then 'renameFolder' else 'renameFile']
      else
        msg = _.sprintf i18n.msgs[if isFolder then 'newFolder' else 'newFile'], if selected? then selected else i18n.labels.rootFolder
      # displays the popup
      popup = utils.popup(title, msg, 'question', [
          text: i18n.labels.create
          icon: 'valid'
          click: =>
            # Do not proceed unless no validation error
            validator.validate()
            return false unless validator.errors.length is 0
            validator.dispose()
            # trim value and creates/move fsItem
            @_createMoveItem popup.find('input.name').val().trim(), isFolder, oldName
        ,
          text: i18n.buttons.cancel
          icon: 'cancel'
          click: => validator.dispose()
        ],
        1).addClass 'name-choose-popup'

      # adds a text field and an error field above it
      input = $('<input type="text" class="name"/>').appendTo popup
      input.val oldName.substring 1+oldName.lastIndexOf conf.separator if oldName?
      popup.append "<div class='errors'></div>"

      # must contains LATIN-1 visible characters except / and \. Can also contain accentuated LATIN-1 supplement.
      # http://fr.wikipedia.org/wiki/Table_des_caract%C3%A8res_Unicode_%280000-0FFF%29
      newRegexp= /^[\u0020-\u002E\u0030-\u005B\u005D-\u007E\u00C0-\u00FF]+$/
      renameRegexp= /^[\u0020-\u007E\u00C0-\u00FF]+$/
      # creates the validator
      validator = new validators.Regexp 
        required: true, 
        spacesAllowed: true, 
        regexp: if oldName? then renameRegexp else newRegexp
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
          text: i18n.buttons.no
          icon: 'invalid'
        ,
          text: i18n.buttons.yes
          icon: 'valid'
          click: => removed.destroy()
        ]

    # **private**
    # Current edited file change handler: updates the button bar consequently
    _onUpdateFileBar: =>
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
      @_uploadButton._setOption 'disabled', fileSelected
      @_renameButton._setOption 'disabled', selected is null
      @_removeFolderButton._setOption 'disabled', selectedItem is null or ! selectedItem.get 'isFolder'
      @_onUpdateFileBar()

    # **private**
    # Upload handler: once a file have been selected, upload it to server
    _onFileChoosen: =>
      # Retrieve uploaded file
      file = @$el.find('.file-upload > input')[0].files[0]
      path = "#{if @_explorer.selected? then "#{@_explorer.selected}#{conf.separator}" else ''}#{file.name}"

      # Read its content
      reader = new FileReader()
      
      reader.onload = (event) =>
        # once read, create the FSItem.
        @_createInProgress = new FSItem
          path: path
          isFolder: false
          # Removes the descriptor and put in utf8 because save will translate it into base64
          content: atob event.target.result.replace "data:#{file.type};base64,", ''
        # and save it on server
        @_createInProgress.save()

      # read data from file as base64 string
      reader.readAsDataURL file