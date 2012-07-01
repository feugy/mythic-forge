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
  'i18n!nls/widget'
  'widget/baseWidget'
   # @todo 'widget/instanceList'
],  (i18n) ->

  # The property widget allows to display and edit a type's property. 
  # It adapts to the property's own type.
  Property =
    
    options:     
      
      # maximum value for type `integer` or `float`
      max: 100000000000
      
      # minimum value for type `integer` or `float`
      min: -100000000000

      # property's type: string, text, boolean, integer, float, date, array or object
      type: 'string'
      
      # property's value. Null by default
      value: null
      
      # if true, no `null` isn't a valid value. if false, a checkbox is added to specify null value.
      allowNull: true
      
      # differentiate the instance and type behaviour.
      isInstance: false

      # different classes accepted for values inside arrays and objects properties
      accepted: []
      
      # this  is called to display the property's tooltip.
      # it must return a string or null
      tooltipFct: null

    # destructor: free DOM nodes and handles
    destroy: ->
      @element.find('*').unbind 
      $.Widget.prototype.destroy.apply @, arguments

    # build rendering
    _create: ->
      @element.addClass 'property-widget'
      # first cast
      @_castValue()
      rendering = null
      isNull = ! @options.value?
      # depends on the type
      switch @options.type
        when 'string'
          # simple text input
          rendering = $("""<input type="text" value="#{@options.value}"/>""").appendTo @element
          rendering.keyup (event) => @_onChange event
          unless isNull
            @options.value = rendering.val()
          else 
            rendering.attr 'disabled', 'disabled'

        when 'text'
          # textarea
          rendering = $("""<textarea>#{@options.value or ''}</textarea>""").appendTo @element
          rendering.keyup (event) => @_onChange event
          unless isNull 
            @options.value = rendering.val()
          else if @options.allowNull
            rendering.attr 'disabled', 'disabled'
        
        when 'boolean'
          # checkbox 
          rendering = $("""
            <input class="boolean-value" type="checkbox" 
              #{if @optionvalue then 'checked="checked"'}/>
            """).appendTo @element 
          rendering.change (event) => @_onChange event

        when 'integer', 'float'
          # stepper
          step =  if @options.type is 'integer' then 1 else 0.01
          rendering = $("""
            <input type="number" min="#{@options.min}" 
                   max="#{@options.max}" step="#{step}" 
                   value="#{@options.value}"/>""").appendTo @element
          rendering.bind 'change keyup', (event) => @_onChange event
          if $.browser.mozilla 
            rendering.attr 'name', parseInt Math.random *1000000000
            # we must use a widget on firefox       
            rendering.numeric 
              buttons: true
              minValue: @options.min
              maxValue: @options.max
              increment: step
              smallIncrement: step
              largeIncrement: step
              emptyValue: false
              format: 
                format: if step is 0.01 then '0.##' else '0'
                decimalChar: '.'
              title: ''
            
            rendering.numeric 'option', 'disabled', isNull
            # weirdly, the value is initialized to 0
            if isNull
              @options.value = null  
            else 
              @options.value = rendering.val()
              @_castValue()
              
          else 
            unless isNull 
              @options.value = rendering.val()
              @_castValue()
            else 
              rendering.attr 'disabled', 'disabled'
        
        when 'object', 'array'  
          if @options.isInstance 
            # for instances, use a list widget
            rendering = $('<ul class="instance"></ul>').instanceList(
              value: @options.value
              onlyOne: type is 'object'
              dndType: 'todo'
              change: @_onChanged
              tooltipFct: @options.tooltipFct,
              accepted: @options.accepted
              objectEdited: (event, details) =>
                @_trigger 'objectEdited', event, details
              objectRemoved: (event, details) =>
                @_trigger 'objectRemoved', event, details
            ).appendTo @element      

            @options.value = rendering.instanceList 'option', 'value'
            rendering.setOption 'change', (event) => @_onChange event

          else 
            # for type, use a select.
            markup += """<option value="#{spec.val}" 
                #{if @options.value is spec.val then 'selected="selected"'}>spec.name
              </option>""" for spec in i18n.property.objectTypes
            rendering = $("<select>#{markup}</select>").appendTo(@element).change (event) => @_onChange event
            @options.value = rendering.val() 
        
        else throw new Error "unsupported property type #{@options.type}"
       
      # adds the null value checkbox if needed
      return if !@options.allowNull or @options.type is 'object' or @options.type is 'array'
      @element.append("""<input class="isNull" type="checkbox" #{if isNull then 'checked="checked"'} 
        /><span>#{i18n.property.isNull}</span>""").change (event) => @_onChange event

    # **private**
    # Enforce for integer, float and boolean value that the value is well casted/
    _castValue: ->
      return unless @options.value?
      switch @options.type
        when 'integer' then @options.value = parseInt @options.value
        when 'float' then @options.value = parseFloat @options.value
        when 'boolean' then @options.value = @options.value is true

    # **private**
    # Content change handler. Update the current value and trigger event `change`
    #
    # @param event [Event] the rendering change event
    _onChange: (event) ->
      target = $(event.target)
      newValue = target.val()
      
      # special case when we set to null.
      if target.hasClass 'isNull'
        newValue = if @element.find('.isNull:checked').length is 1 then null else newValue
        if $.browser.mozilla and @options.type is 'float' or @options.type is 'integer' 
          input = @element.find '*:nth-child 1'
          # Cas particulier des champs numérique sous Firefox.
          input.numeric 'option', 'disabled', newValue is null
          unless newValue?
            input.val ''
          else 
            input.val '0'
            newValue = 0
          
        else 
          unless newValue?
            input.attr 'disabled', 'disabled'.val ''
          else 
            input.removeAttr 'disabled'
            # Pour les numérique, positionne immédiatement à 0.
            if @options.type is 'float' or @options.type is 'integer'
              input.val 0
              newValue = 0 
        
      else if target.hasClass 'booleanValue'
        # checbox
        newValue = @element.find('.booleanValue:checked').length is 1
      else if target.hasClass 'instance' 
        # special case of arrays and objects of instances
        newValue = target.instanceList 'option', 'value'
       
      
      # cast value
      @options.value = newValue
      @_castValue()
      @_trigger 'change', event
      event.stopPropagation 
    
    # **private**
    # Method invoked when the widget options are set. Update rendering if value change.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option
    _setOption: (key, value) ->
      return $.Widget.prototype._setOption.apply @, arguments unless key in ['type', 'value']
      # updates inner option
      @options[key] = value
      return if @_inhibit
      # refresh rendering.
      @element.find('*').unbind().remove 
      @element.html ''
      # inhibition flag: for firefox and numeric types. the `numeric` widget trigger setOption twice
      @_inhibit = true
      @_create()
      @_inhibit = false

  $.widget "rheia.property", $.rheia.baseWidget, Property