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
  'i18n!nls/widget'
  'utils/validators'
  'widget/loadableImage'
  'widget/property'
],  ($, _, i18n, validators, LoadableImage) ->


  # A special loadableImage that allows to input sprite informations.
  # A special data flag is added to the `change` event to differentiate changes from sprite specification
  # from thoses from image upload/removal.
  # When the flag is true, then the changes is not about image source.
  class SpriteImage extends LoadableImage

    # **private**
    # Builds rendering. Adds inputs for image dimensions
    constructor: (element, options) ->
      super element, options

      @options._silent = true
      @$el.addClass 'sprite'
      @$el.hover (event) => 
        @$el.addClass('show').find('.details').transition {opacity:1}, @options.duration
      , (event) =>
        @$el.removeClass('show').find('.details').transition {opacity:0}, @options.duration

      # inputs for width and height
      $("""<div class="dimensions">#{i18n.spriteImage.dimensions}<input type="numer" class="spriteW"/>
        <input type="numer" class="spriteH"/></div>""").appendTo @$el

      $("""<div class="details">
        <h1>#{i18n.spriteImage.sprites}</h1>
        <table>
          <thead>
            <tr>
              <th colSpan="2">#{i18n.spriteImage.name}</th>
              <th>#{i18n.spriteImage.rank}</th>
              <th>#{i18n.spriteImage.number}</th>
              <th>#{i18n.spriteImage.duration}</th>
            </tr>
          </thead>
          <tbody></tbody>
        </table>
        <a href="#" class="add"></a>
      </div>""").appendTo @$el

      @$el.find('.details .add').button(
        label: i18n.spriteImage.add
        icons:
          primary: 'add small'
      ).click (event) => 
        event?.preventDefault()
        @options.sprites[i18n.spriteImage.newName] =
          duration: 0
          number: 0
          rank: @$el.find('.details tbody tr').length
        @_refreshSprites()
        @$el.trigger 'change', isSprite: true

      @_refreshSprites()

      @$el.find('.dimensions input').keyup _.debounce ((event) => @_onDimensionChange event), 300

      @setOption 'spriteW', @options.spriteW
      @setOption 'spriteH', @options.spriteH
      @options._silent = false

    # Method invoked when the widget options are set. Update rendering if `spriteH` or `spriteW` changed.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option    
    setOption: (key, value) =>
      return super key, value unless key in ['spriteW', 'spriteH', 'sprite']
      switch key
        when 'spriteW', 'spriteH' 
          value = parseInt value
          value = 0 if isNaN value
          @options[key] = value
          @$el.find(".#{key}").val value
        when 'sprite'
          @$el.find('.details *').unbind().remove()
          @_refreshSprites()

    # Frees DOM listeners
    dispose: =>
      @$el.find('input').off()
      validator.dispose() for validator in @options._validators
      super()

    # **private**
    # Empties and rebuilds sprite specifications rendering.
    _refreshSprites: =>
      # disposes validators
      validator.dispose() for validator in @options._validators
      @options._validators = []

      # clear existing sprites
      table = @$el.find('.details table tbody').empty()

      # property widget change handler: set property in options, and trigger change event
      onChangeFactory = (key = null) =>
        return (event, arg) => 
          # validates values
          @_validates()
          value = arg.value

          name = $(event.target).closest('tr').data 'name'
          prev = if key? then @options.sprites[name][key] else name 
          return unless value isnt prev
          if key?
            # change a single value 
            @options.sprites[name][key] = value
          else if !(value of @options.sprites)
            # change name, keeping other values, without erasing existing name
            @options.sprites[value] = @options.sprites[name]
            delete @options.sprites[name]
            $(event.target).closest('tr').data 'name', value
          else 
            # add special error to indicate unsave
            @options.errors.push err: 'unsaved', msg: _.sprintf i18n.spriteImage.unsavedSprite, value
            @$el.addClass 'validation-error'

          # the last parameters allow to split changes from the image from those from sprite definition
          @$el.trigger 'change', isSprite: true unless @options._silent

      for name, spec of @options.sprites
        line = $("""<tr data-name="#{name}">
            <td><a href="#"></a></td>
            <td><div class="name"></div></td>
            <td><div class="rank"></div></td>
            <td><div class="number"></div></td>
            <td><div class="duration"></div></td>
          </tr>""").appendTo table
        # creates widgets for edition
        line.find('.rank').property
          type: 'integer'
          value: spec.rank
          allowNull: false
          change: onChangeFactory 'rank'

        line.find('.name').property
          type: 'string'
          value: name
          allowNull: false
          change: onChangeFactory()

        line.find('.number').property
          type: 'integer'
          value: spec.number
          allowNull: false
          change: onChangeFactory 'number'

        line.find('.duration').property
          type: 'integer'
          value: spec.duration
          allowNull: false
          change: onChangeFactory 'duration'

        line.find('td > a').button(
          icons:
            primary: 'remove x-small'
        ).click (event)=>
          event.preventDefault()
          delete @options.sprites[$(event.target).closest('tr').data 'name']
          @_refreshSprites()
          @_validates()
          @$el.trigger 'change', isSprite: true
        
        # creates a validator for name.
        @options._validators.push new validators.String {required: true},
          i18n.spriteImage.name, line.find('.name input'), null

    # **private**
    # Validates each created validators, and fills the `errors` attribute. 
    # Toggles the error class on the widget's root.
    _validates: =>
      @options.errors = []
      @options.errors = @options.errors.concat validator.validate() for validator in @options._validators
      @$el.toggleClass 'validation-error', @options.errors.length isnt 0

    # **private**
    # hanlder that validates dimensions.
    #
    # @param event [Event] change event on dimension imputs
    _onDimensionChange: (event) =>
      for key in ['spriteW', 'spriteH']
        value = parseInt @$el.find(".#{key}").val()
        value = 0 if isNaN value
        @$el.find(".#{key}").val value
        @options[key] = value
      @$el.trigger 'change', isSprite: true unless @options._silent

  # widget declaration
  SpriteImage._declareWidget 'spriteImage', $.extend true, {}, $.fn.loadableImage.defaults, 

    # sprite width, set with the dedicated input
    # read-only: use `setOption('spriteW')` to modify
    spriteW: 0

    # sprite height, set with the dedicated input
    # read-only: use `setOption('spriteH')` to modify
    spriteH: 0

    # sprites definition.
    # read-only: use `setOption('sprite')` to modify
    sprites: {}

    # show/hide duration in milliseconds
    duration: 250

    # list of validation errors, when the rendering changes.
    # an empty list means no error.
    errors:[]
    
    # **private**
    # inhibit the change event if necessary.
    _silent: false

    # **private**
    # validators for names
    _validators: []