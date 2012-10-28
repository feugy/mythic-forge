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
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

define [
  'jquery'
  'underscore'
  'ace/ace'
  'i18n!nls/widget'
  'widget/baseWidget'
],  ($, _, ace, i18n) ->

  prompt = "<div class='prompt'>"+
    "<div class='find'>"+
      "<span>#{i18n.advEditor.find}</span>"+
        "<input type='text'/>"+
        "<a class='previous icon' href='#' title='#{i18n.advEditor.findPrev}'><i class='ui-icon ui-icon-carat-1-n'></i></a>"+
        "<a class='next icon' href='#' title='#{i18n.advEditor.findNext}'><i class='ui-icon ui-icon-carat-1-s'></i></a>"+
        "<a class='close icon' href='#'><i class='ui-icon ui-icon-close'></i></a>"+
      "</div>"+
      "<div class='replace'>"+
        "<span>#{i18n.advEditor.replaceBy}</span>"+
        "<input type='text'/>"+
        "<a class='first icon' href='#' title='#{i18n.advEditor.replace}'><i class='ui-icon ui-icon-transfer-e-w'></i></a>"+
        "<a class='all icon' href='#' title='#{i18n.advEditor.replaceAll}'><i class='ui-icon ui-icon-transferthick-e-w'></i></a>"+
      "</div>"+
    "</div>"

  # set path to avoid problems after optimization
  path = requirejs.s.contexts._.config.baseUrl+requirejs.s.contexts._.config.paths.ace
  ace.config.set 'modePath', path
  ace.config.set 'themePath', path
  ace.config.set 'workerPath', path

  # Widget that encapsulate the Ace editor to expose a more jQuery-ui compliant interface
  # Triggers a `change`event when necessary.
  $.widget 'rheia.advEditor', $.rheia.baseWidget,

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

    # **private**
    # prompt to get find commands
    _prompt: null

    # Frees DOM listeners
    destroy: ->
      @_editor.destroy()
      $.rheia.baseWidget::destroy.apply @, arguments

    # **private**
    # Builds rendering
    _create: ->
      $.rheia.baseWidget::_create.apply @, arguments
      
      @element.addClass 'adv-editor'

      # creates and wire the editor
      node = $('<div></div>').appendTo @element
      @_editor = ace.edit node[0]
      session = @_editor.getSession()
      
      session.on 'change', => 
        # update inner value and fire change event
        @options.text = @_editor.getValue()
        @_trigger 'change', null, @options.text
      
      # configure it
      session.setUseSoftTabs true

      # special implementation of find command
      @_editor.commands.addCommand
        name: 'find'
        bindKey: win:'Ctrl-F', mac:'Command-F'
        exec: =>
          selection = @_editor.session.getTextRange @_editor.getSelectionRange()
          @_prompt.find('.find input').val selection if selection
          @_prompt.removeClass('and-replace').addClass 'shown'
          @_prompt.find('.find input').focus()

      # special implementation of replace command
      @_editor.commands.addCommand
        name: 'replace'
        bindKey: win:'Ctrl-H', mac:'Command-Option-F'
        exec: =>
          selection = @_editor.session.getTextRange @_editor.getSelectionRange()
          @_prompt.find('.find input').val selection if selection
          @_prompt.addClass('and-replace').addClass 'shown'
          @_prompt.find('.find input').focus()

      # fills its content
      @_setOption 'text', @options.text
      @_setOption 'tabSize', @options.tabSize
      @_setOption 'theme', @options.theme
      @_setOption 'mode', @options.mode
            
      # creates prompt
      @_prompt = $(prompt).appendTo @element

      @_prompt.on 'keyup', '.find input', _.debounce ( =>
        @_editor.findAll @_prompt.find('.find input').val(), {}, true
      ), 300

      @_prompt.on 'click', '.previous', => @_editor.findPrevious {}, true
      @_prompt.on 'click', '.next', => @_editor.findNext {}, true
      @_prompt.on 'click', '.close', => 
        @_prompt.removeClass 'shown'
        @_editor.focus()
      @_prompt.on 'click', '.first', => 
        @_editor.replace @_prompt.find('.replace input').val(), needle: @_prompt.find('.find input').val()
      @_prompt.on 'click', '.all', =>
        @_editor.replaceAll @_prompt.find('.replace input').val(), needle: @_prompt.find('.find input').val()

    # **private**
    # Method invoked when the widget options are set. Update rendering if `source` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    _setOption: (key, value) ->
      return $.rheia.baseWidget::_setOption.apply @, arguments unless key in ['text', 'mode', 'theme', 'tabSize']
      switch key
        when 'text' 
          # keeps the undo manager
          undoMgr = @_editor.getSession().getUndoManager()
          # keeps the cursor position if possible
          position = @_editor.selection.getCursor()
          @_editor.setValue value
          # setValue will select all new text. rheiaeset the cursor to original position.
          @_editor.clearSelection()
          @_editor.selection.moveCursorToPosition position
          @_editor.getSession().setUndoManager undoMgr
        when 'tabSize'
          @options.tabSize = value
          @_editor.getSession().setTabSize value
        when 'theme'
          @options.theme = value
          @_editor.setTheme "ace/theme/#{value}"
        when 'mode'
          value = 'less' if value is 'stylus'
          @options.mode = value
          @_editor.getSession().setMode "ace/mode/#{value}"
    