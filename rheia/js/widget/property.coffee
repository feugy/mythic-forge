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
  'moment'
  'i18n!nls/common'
  'i18n!nls/widget'
  'widget/base'
  'widget/instanceList'
],  ($, moment, i18n, i18nWidget, Base) ->

  i18n = $.extend true, i18n, i18nWidget

  # The property widget allows to display and edit a type's property. 
  # It adapts to the property's own type.
  class Property extends Base
    
    constructor: (element, options) ->
      super element, options
      @_create()

    # destructor: free DOM nodes and handles
    dispose: =>
      @$el.find('*').off()
      super()
    
    # Method invoked when the widget options are set. Update rendering if value change.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option
    setOption: (key, value) =>
      return unless key in ['type', 'value']
      # updates inner option
      @options[key] = value
      return if @_inhibit
      # refresh rendering.
      @$el.find('*').unbind().remove()
      @$el.html ''
      # inhibition flag: for firefox and numeric types. the `numeric` widget trigger setOption twice
      @_inhibit = true
      @_create()
      @_inhibit = false

    # build rendering
    _create: =>
      @$el.addClass 'property-widget'
      # first cast
      @_castValue()
      rendering = null
      isNull = @options.value is null or @options.value is undefined
      # depends on the type
      switch @options.type
        when 'string'
          # simple text input
          rendering = $("""<input type="text" value="#{@options.value}"/>""").appendTo @$el
          rendering.on 'keyup', @_onChange
          unless isNull
            @options.value = rendering.val()
          else if @options.allowNull
            rendering.attr 'disabled', 'disabled'

        when 'text'
          # textarea
          rendering = $("""<textarea>#{@options.value or ''}</textarea>""").appendTo @$el
          rendering.on 'keyup', @_onChange
          unless isNull 
            @options.value = rendering.val()
          else if @options.allowNull
            rendering.attr 'disabled', 'disabled'
        
        when 'boolean'
          # checkbox 
          group = parseInt Math.random()*1000000000
          rendering = $("""
            <span class="boolean-value">
              <input name="#{group}" value="true" type="radio" #{if @options.value is true then 'checked="checked"'}/>
              #{i18n.property.isTrue}
              <input name="#{group}" value="false" type="radio" #{if @options.value is false then 'checked="checked"'}/>
              #{i18n.property.isFalse}
            </span>
            """).appendTo @$el
          rendering.find('input').on 'change', @_onChange
          if isNull
            rendering.find('input').attr  'disabled', 'disabled'

        when 'integer', 'float'
          # stepper
          step =  if @options.type is 'integer' then 1 else 0.01
          rendering = $("""
            <input type="number" min="#{@options.min}" 
                   max="#{@options.max}" step="#{step}" 
                   value="#{@options.value}"/>""").appendTo @$el
          rendering.on 'change keyup', @_onChange
          if $.browser.mozilla 
            # we must use a widget on firefox       
            rendering.attr('name', parseInt Math.random()*1000000000)
              .focus(() ->  $(this).parent().addClass 'focus')
              .blur(() -> $(this).parent().removeClass 'focus')
              .numeric
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
            # uses instalceList widget if we're displaying an instance property
            rendering = $('<ul class="instance"></ul>').instanceList(
              value: @options.value
              onlyOne: @options.type is 'object'
              dndType: i18n.constants.instanceAffectation
              tooltipFct: @options.tooltipFct
              accepted: @options.accepted
            ).on('change', @_onChange
            ).on('click', (event, instance) =>
              @$el.trigger 'open', instance
            ).appendTo @$el

            @options.value = rendering.data('instanceList')?.options.value

          else 
            # for type, use a select.
            markup = ""
            markup += """<option value="#{spec.val}" 
                #{if @options.value is spec.val then 'selected="selected"'}>#{spec.name}
              </option>""" for spec in i18n.property.objectTypes
            rendering = $("<select>#{markup}</select>").appendTo(@$el).on 'change', @_onChange
            @options.value = rendering.val() 
        
        when 'date'
          rendering = $("""<input type="text" #{if isNull then 'disabled="disabled"'}/>""").datetimepicker(
            showSecond: true
            # unfortunately, moment and jquery datetimepiker do not share their formats...
            dateFormat: i18n.constants.dateFormat.toLowerCase()
            timeFormat: i18n.constants.timeFormat.toLowerCase()
          ).appendTo(@$el).on 'change', @_onChange

          rendering.datetimepicker 'setDate', new Date @options.value unless isNull

          @options.value = rendering.val() 
          @_castValue()

        else throw new Error "unsupported property type #{@options.type}"
       
      # adds the null value checkbox if needed
      return if !@options.allowNull or @options.type is 'object' or @options.type is 'array'
      $("""<input class="isNull" type="checkbox" #{if isNull then 'checked="checked"'} 
        /><span>#{i18n.property.isNull}</span>""").appendTo(@$el).on 'change', @_onChange

    # **private**
    # Enforce for integer, float and boolean value that the value is well casted/
    _castValue: =>
      return unless @options.value?
      switch @options.type
        when 'integer' then @options.value = parseInt @options.value
        when 'float' then @options.value = parseFloat @options.value
        when 'boolean' then @options.value = @options.value is true or @options.value is 'true'
        when 'date' 
          # null and timestamp values are not modified.
          if @options.value isnt null and isNaN @options.value
            # date and string values will be converted to timestamp
            @options.value = moment(@options.value).toDate().toISOString()

    # **private**
    # Content change handler. Update the current value and trigger event `change`
    #
    # @param event [Event] the rendering change event
    _onChange: (event) =>
      target = $(event.target)
      newValue = target.val()
      
      # special case when we set to null.
      if target.hasClass 'isNull'
        isNull =  @$el.find('.isNull:checked').length is 1
        input = @$el.find '*:nth-child(1)'
        
        switch @options.type
          when 'float', 'integer'
            newValue = if isNull then null else 0
            if $.browser.mozilla
              # in mozilla we're using a widget
              input.numeric 'option', 'disabled', isNull
              input.val '0' unless isNull
            else 
              if isNull
                input.val ''
                input.attr 'disabled', 'disabled'
              else 
                input.val 0
                input.removeAttr 'disabled'
          
          when 'boolean'
            if isNull
              target.prev('.boolean-value').find('input').attr 'disabled', 'disabled'
              newValue = null
            else 
              target.prev('.boolean-value').find('input').removeAttr 'disabled'
              newValue = target.prev('.boolean-value').find('input:checked').val()
        
          else # date, string, text
            if isNull
              input.attr('disabled', 'disabled').val ''
              newValue = null
            else 
              input.removeAttr 'disabled'
              newValue = input.val()
              if @options.type is 'date'
                newValue = moment(newValue, "#{i18n.constants.dateFormat} #{i18n.constants.timeFormat}").toDate().toISOString()
        
      else if target.hasClass 'instance'
        # special case of arrays and objects of instances
        newValue = target.data('instanceList')?.options.value
      
      # cast value
      @options.value = newValue
      @_castValue()
      @$el.trigger 'change', value:@options.value
      event.stopPropagation()

  # widget declaration
  Property._declareWidget 'property', 

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