###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
     at your option any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
###
'use strict'

define [
  'jquery'
  'ace/ace'
  'widget/baseWidget'
],  ($, ace) ->


  # Widget that encapsulate the Ace editor to expose a more jQuery-ui compliant interface
  # Triggers a `change`event when necessary.
  AdvEditor = 

    options:    

      # the edited text
      # read-only: use `setOption('text')` to modify.
      text: ''

      # mode used to parse content, 'text' by default.
      # read-only: use `setOption('mode')` to modify.
      mode: 'text'
 
      # theme used to display content, 'clouds' by default.
      # read-only: use `setOption('theme')` to modify.
      theme: 'clouds'

      # number of spaces used to replace tabs, 2 by default.
      # read-only: use `setOption('tabSize')` to modify.
      tabSize: 2

      # **private**
      # the ace editor
      _editor: null

    # Frees DOM listeners
    destroy: () ->
      @_editor.destroy()
      $.Widget.prototype.destroy.apply(@, arguments)

    # **private**
    # Builds rendering
    _create: () ->
      @element.addClass('adv-editor')
      
      # creates and wire the editor
      @options._editor = ace.edit(@element[0])
      session = @options._editor.getSession()
      
      session.on('change', () => 
        # update inner value and fire change event
        @options.text = @options._editor.getValue()
        @_trigger('change', null, @options.text)
      )
      
      # configure it
      session.setUseSoftTabs(true);

      # fills its content
      @_setOption('text', @options.text)
      @_setOption('tabSize', @options.tabSize)
      @_setOption('theme', @options.theme)
      @_setOption('mode', @options.mode)

    # **private**
    # Method invoked when the widget options are set. Update rendering if `source` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.Widget.prototype._setOption.apply(@, arguments) unless key in ['text', 'mode', 'theme', 'tabSize']
      switch key
        when 'text' 
          # keeps the undo manager
          undoMgr = @options._editor.getSession().getUndoManager()
          # keeps the cursor position if possible
          position = @options._editor.selection.getCursor()
          @options._editor.setValue(value)
          # setValue will select all new text. rheiaeset the cursor to original position.
          @options._editor.clearSelection()
          @options._editor.selection.moveCursorToPosition(position)
          @options._editor.getSession().setUndoManager(undoMgr)
        when 'tabSize'
          @options.tabSize = value
          @options._editor.getSession().setTabSize(value)
        when 'theme'
          @options.theme = value
          require(["ace/theme/#{value}"], () => @options._editor.setTheme("ace/theme/#{value}"))
        when 'mode'
          @options.mode = value
          require(["ace/mode/#{value}"], () => @options._editor.getSession().setMode("ace/mode/#{value}"))

  $.widget("rheia.advEditor", $.rheia.baseWidget, AdvEditor)
    