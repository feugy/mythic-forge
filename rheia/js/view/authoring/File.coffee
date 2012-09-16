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
  'view/BaseView'
  'i18n!nls/common'
  'i18n!nls/authoring'
  'model/FSItem'
  'widget/advEditor'
], ($, _, BaseView, i18n, i18nAuthoring, FSItem) ->

  i18n = $.extend(true, i18n, i18nAuthoring)

  # map that indicates to which extension corresponds which editor mode
  # extensions are keys, mode are values
  extToMode =
    'coffee': 'coffee'
    'json': 'json'
    'js': 'javascript'
    'html': 'html'
    'htm': 'html'
    'css': 'css'
    'xml': 'xml'
    'svg': 'svg'
    'yaml': 'yaml'
    'yml': 'yaml'
    'stylus': 'stylus'
    'styl': 'stylus'
    'png': 'img'
    'jpg': 'img'
    'jpeg': 'img'
    'gif': 'img'

  # Returns the supported mode of a given file
  #
  # @param item [FSItem] the concerned item
  # @return the supported mode
  getMode = (item) ->
    if item.extension of extToMode then extToMode[item.extension] else 'text'

  # View that allows to edit files
  class FileView extends BaseView

    # **private**
    # models collection on which the view is bound
    _collection: FSItem.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeFileConfirm
    
    # **private**
    # close popup confirmation text, that can take the edited object's name in parameter
    _confirmCloseMessage: i18n.msgs.closeFileConfirm

    # **private**
    # name of the model attribute that holds name.
    _nameAttribute: 'path'

    # **private**
    # file mode
    _mode: 'text'

    # **private**
    # widget that allows content edition
    _editorWidget: null

    # **private**
    # File rendering in image mode
    _image: null

    # The view constructor. The edited file system item must be a file, with its content poplated
    #
    # @param file [FSItem] the edited object.
    constructor: (id) ->
      super id, 'file'
      
      if id?
        # get the file content, and display when arrived without external warning
        @_saveInProgress = true
        FSItem.collection.fetch item:@model

    # Returns the view's title
    #
    # @return the edited object name.
    getTitle: => @model.id.substring @model.id.lastIndexOf('\\')+1

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    _specificRender: =>
      @className += " #{getMode @model}"

      # instanciate the content editor
      @_editorWidget = $('<div class="content"></div>').advEditor(
        change: @_onChange
      ).data 'advEditor'
      @$el.empty().append @_editorWidget.element

      @_image = $('<img/>').appendTo @$el

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: => 
      @model.set 'content', @_editorWidget.options.text unless @_mode is 'img'
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      @_mode = getMode @model
      @$el.toggleClass 'image', @_mode is 'img'
      if @_mode is 'img'
        # hide editor and display an image instead
        @_editorWidget.element.hide()
        imageType = "image/#{@model.extension}"
        @_image.attr 'src', "data:#{imageType};base64,#{btoa @model.get 'content'}"
      else
        @_editorWidget.element.show()
        @_editorWidget.setOption 'mode', @_mode
        @_editorWidget.setOption 'text', @model.get 'content'

      # to update displayed icon
      @_onChange()

    # **private**
    # Change handler, wired to any changes from the rendering.
    # Detect text changes and triggers the change event.
    _onChange: =>
      if @_mode is 'img'
        @_canSave = false
      else
        @_canSave = @model.get('content') isnt @_editorWidget.options.text 
      super()

    # **private**
    # Invoked when a model is removed from the server.
    # Close the view if the removed object corresponds to the edited one.
    #
    # @param removed [FSItem] the removed model
    # @parma collection [FSItem.collection] the concerned collection
    # @param options [Object] remove event options
    _onRemoved: (removed, collection, options) =>
      # Automatically remove without notification if a parent folder was removed, or if was moved
      if (removed.id isnt @model.id and 0 is @model.id.indexOf removed.id) or (removed.id is @model.id and options?.move)
        @_removeInProgress = false;
        @_isClosing = true
        return @trigger 'close'
      # superclass behaviour
      super removed