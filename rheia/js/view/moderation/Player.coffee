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
  'moment'
  'utils/utilities'
  'utils/validators'
  'i18n!nls/common'
  'i18n!nls/moderation'
  'text!tpl/player.html'
  'view/BaseEditionView'
  'model/Player'
  'widget/property'
  'widget/advEditor'
], ($, _, moment, utils, validators, i18n, i18nModeration, template, BaseEditionView, Player) ->

  i18n = $.extend true, i18n, i18nModeration

  # Displays and edit a player on moderation perspective
  class PlayerView extends BaseEditionView

    events:
      'change .provider.field': '_onProviderChanged'
      'change .isAdmin.field': '_onChange'

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: Player.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removePlayerConfirm

    # **private**
    # Password need to be validated only if plyaer is new or if field has been changed
    _passwordChanged: false

    # **private**
    # Button to kick user
    _kickButton: null

    # **private**
    # Widget to display email
    _emailWidget: null

    # **private**
    # Widget to display character list
    _charactersWidget: null

    # **private**
    # Widget to manage authentication provider
    _providerWidget: null

    # **private**
    # Widget to set password for manually provided players
    _passwordWidget: null

    # **private**
    # Widget to set the administration right
    _isAdminCheckbox: null

    # **private**
    # Widget to set the player's first name
    _firstNameWidget: null

    # **private**
    # Widget to set the player's last name
    _lastNameWidget: null

    # **private**
    # Widget to dislpay and change the last connection date
    _lastConnectionWidget: null

    # **private**
    # Widget to edit user preferences
    _prefsEditor: null

    # The view constructor.
    #
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id) ->
      super id, 'player'
      # Closes external changes warning after 5 seconds
      @_emptyExternalChange = _.debounce (=> @$el.find('.external-change *').hide 200, -> $(@).remove()), 5000

      @bindTo Player.collection, 'connectedPlayersChanged', (connected, disconnected) =>
        return unless @_kickButton?
        # update kick button's state regarding the presence of model's email in a list
        if @model.email in disconnected
          @_kickButton.button 'option', 'disabled', true
        else if @model.email in connected
          @_kickButton.button 'option', 'disabled', false

      console.log "creates player moderation view for #{if id? then @model.id else 'a new player'}"

    # Returns the view's title
    #
    # @param confirm [Boolean] true to get the version of the title for confirm popups. Default to false.
    # @return the edited object name.
    getTitle: (confirm = false) => 
      return @_emailWidget?.options.value or @model.email if confirm
      "#{_.truncate (@_emailWidget?.options.value or @model.email), 15}<div class='uid'>&nbsp;</div>"

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new Player()
      @model.provider = null # manual provider
      @model.email = i18n.labels.newEmail
      @model.isAdmin = false
      
    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      # data needed by the template
      title: _.sprintf i18n.titles.player, @model.email, @model.id
      i18n: i18n

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    _specificRender: =>
      # wired kick button
      @_kickButton = @$el.find('.kick').button(
        label: i18n.buttons.kick
        disabled: !(@model.email in Player.collection.connected)
      ).on 'click', => 
        # do not kick unsaved users
        return if @_tempId?
        Player.collection.kick @model.email

      # create specific field widgets
      @_emailWidget = @$el.find('.email.field').property(
        type: 'string'
        allowNull: false
      ).on('change', @_onChange
      ).data 'property'

      @_charactersWidget = @$el.find('.characters.field').property(
        type: 'array'
        isInstance: true
        accepted: ['Item']
        tooltipFct: utils.instanceTooltip
      ).on('change', @_onChange
      ).on('open', (event, instance) =>
        # opens items
        app.router.trigger 'open', instance._className, instance.id
      ).data 'property'

      @_passwordWidget = @$el.find('.password .right > *').property(
        type: 'string'
        allowNull: false
      ).on('change', => 
        @_passwordChanged = true
        @_onChange()
      ).data 'property'

      @_providerWidget = @$el.find '.provider.field'

      @_isAdminCheckbox = @$el.find '.isAdmin.field'

      @_firstNameWidget = @$el.find('.firstName.field').property(
        type: 'string'
        allowNull: false
      ).on('change', @_onChange
      ).data 'property'

      @_lastNameWidget = @$el.find('.lastName.field').property(
        type: 'string'
        allowNull: false
      ).on('change', @_onChange
      ).data 'property'

      @_lastConnectionWidget = @$el.find('.lastConnection.field').property(
        type: 'date'
        allowNull: true
      ).on('change', @_onChange
      ).data 'property'

      @_prefsEditor = @$el.find('.prefs .field').advEditor(
        mode: 'json'
      ).on('change', @_onChange
      ).data 'advEditor'

      super()
      
    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      # superclass handles email
      super()

      @model.characters = @_charactersWidget.options.value?.concat() or []
      @model.provider = @_providerWidget.val() or null
      if @_passwordChanged
        @model.password = if @model.provider? then undefined else @_passwordWidget.options.value
      @model.isAdmin = @_isAdminCheckbox.is ':checked'
      @model.email = @_emailWidget.options.value
      @model.firstName = @_firstNameWidget.options.value
      @model.lastName = @_lastNameWidget.options.value
      @model.lastConnection = @_lastConnectionWidget.options.value or null
      @model.prefs = JSON.parse @_prefsEditor.options.text

    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>

      # update view title
      @$el.find('> h1').html @_getRenderData().title

      @_passwordChanged = @_isNew
      @_charactersWidget.setOption 'value', @model.characters?.concat() or []
      @_providerWidget.val @model.provider
      @_passwordWidget.setOption 'value', unless @model.provider? then '' else @model.password
      @_isAdminCheckbox.attr 'checked', @model.isAdmin
      @_emailWidget.setOption 'value', @model.email or ''
      @_firstNameWidget.setOption 'value', @model.firstName or ''
      @_lastNameWidget.setOption 'value', @model.lastName or ''
      @_lastConnectionWidget.setOption 'value', @model.lastConnection
      @_prefsEditor.setOption 'text', JSON.stringify @model.prefs or {}, null, '\t'

      # superclass handles description email and trigger _onChange
      super()

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      # superclass handles description image, name and description 
      comparable = super()

      comparable.push
        name: 'provider'
        original: @model.provider
        current: @_providerWidget.val() or null
      ,
        name: 'isAdmin'
        original: @model.isAdmin
        current: @_isAdminCheckbox.is ':checked'
      ,
        name: 'email'
        original: @model.email
        current: @_emailWidget.options.value
      ,
        name: 'lastName'
        original: @model.lastName
        current: @_lastNameWidget.options.value
      ,
        name: 'firstName'
        original: @model.firstName
        current: @_firstNameWidget.options.value
      ,
        name: 'lastConnection'
        original: @model.lastConnection
        current: @_lastConnectionWidget.options.value or null
      ,
        name: 'characters'
        original: @model.characters
        current: @_charactersWidget.options.value
      ,
        name: 'prefs'
        original: @model.prefs
        current: JSON.parse(@_prefsEditor.options.text) or {}

      if @_passwordChanged
        comparable.push
          name: 'password'
          original: null # no password known :)
          current: @_passwordWidget.options.value

      comparable

    # **private**
    # Re-creates validators, when refreshing the properties.
    # Existing validators are trashed, and validators created for:
    # - login (inheritted method)
    # - password (if provider is null)
    _createValidators: =>
      super()
      # adds a validator for login
      @_validators.push new validators.Regexp
        invalidError: i18n.msgs.invalidEmail
        regular: i18n.constants.emailRegex
      , i18n.labels.email, @_emailWidget.$el, null, (node) -> node.find('input').val()

      # adds a validator for password if provider is defined
      @_validators.push new validators.Handler
        handler: (value) => 
          # always allow if provider defined
          return null if @_providerWidget.val() or !@_passwordChanged
          return _.sprintf(i18n.validator.required, i18n.labels.password) if value?.length is 0
          return _.sprintf(i18n.validator.spacesNotAllowed, i18n.labels.password) if value.match /\s/
          null
          
      , i18n.labels.password, @_passwordWidget.$el, null, (node) -> node.find('input').val()

    # **private**
    # Allows to compute the rendering's validity.
    # 
    # @return true if all rendering's fields are valid
    _specificValidate: =>
      try 
        JSON.parse @_prefsEditor.options.text
        []
      catch err
        [msg: _.sprintf i18n.msgs.invalidPrefs]

    # **private**
    # Avoid warning popup when edited object have been modified externally, and temorary displays a warning inside tab.
    _notifyExternalChange: =>
      @_emptyExternalChange()
      if @$el.find('.external-change *').length is 0
        @$el.find('.external-change').append "<p>#{i18n.msgs.playerExternalChange}</p>"

    # **private**
    # When changing provider, we must toggle the password field also
    _onProviderChanged: =>
      provider = @_providerWidget.val() or null

      # hide password if provider is defined
      @$el.find('.password').toggle !(provider?)
      @_passwordWidget.setOption 'value', '' if provider?

      @_onChange()
