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
    # 'Name' of a player is its email.
    _nameAttribute: 'email'

    # **private**
    # Error display name for fields that holds model's name.
    _nameDisplayLabel: i18n.labels.email

    # **private**
    # Password need to be validated only if plyaer is new or if field has been changed
    _passwordChanged: false

    # **private**
    # Button to kick user
    _kickButton: null

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
        if @model.get('email') in disconnected
          @_kickButton.button 'option', 'disabled', true
        else if @model.get('email') in connected
          @_kickButton.button 'option', 'disabled', false

      console.log "creates player moderation view for #{if id? then @model.id else 'a new player'}"

    # Returns the view's title
    #
    # @param confirm [Boolean] true to get the version of the title for confirm popups. Default to false.
    # @return the edited object name.
    getTitle: (confirm = false) => 
      return @_nameWidget?.options.value or @model.get @_nameAttribute if confirm
      "#{_.truncate (@_nameWidget?.options.value or @model.get @_nameAttribute), 15}<div class='uid'>&nbsp;</div>"

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new Player()
      @model.set 'provider', null # manual provider
      @model.set 'email', i18n.labels.newEmail
      @model.set 'isAdmin', false
      
    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      # data needed by the template
      {
        title: _.sprintf i18n.titles.player, @model.get('email'), if @_tempId? then i18n.labels.newType else @model.id
        i18n: i18n
      }

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    _specificRender: =>
      # wired kick button
      @_kickButton = @$el.find('.kick').button(
        label: i18n.buttons.kick
        disabled: !(@model.get('email') in Player.collection.connected)
      ).on 'click', => 
        # do not kick unsaved users
        return if @_tempId?
        Player.collection.kick @model.get 'email'

      # create specific field widgets
      @_charactersWidget = @$el.find('.characters.field').property(
        type: 'array'
        isInstance: true
        accepted: ['Item']
        tooltipFct: utils.instanceTooltip
        change: @_onChange
        open: (event, instance) =>
          # opens items
          rheia.router.trigger 'open', instance.constructor.name, instance.id
      ).data 'property'

      @_passwordWidget = @$el.find('.password .right > *').property(
        type: 'string'
        allowNull: false
        change: => 
          @_passwordChanged = true
          @_onChange()
      ).data 'property'

      @_providerWidget = @$el.find '.provider.field'

      @_isAdminCheckbox = @$el.find '.isAdmin.field'

      @_firstNameWidget = @$el.find('.firstName.field').property(
        type: 'string'
        allowNull: false
        change: @_onChange
      ).data 'property'

      @_lastNameWidget = @$el.find('.lastName.field').property(
        type: 'string'
        allowNull: false
        change: @_onChange
      ).data 'property'

      @_lastConnectionWidget = @$el.find('.lastConnection.field').property(
        type: 'date'
        allowNull: true
        change: @_onChange
      ).data 'property'

      @_prefsEditor = @$el.find('.prefs .field').advEditor(
        mode: 'json'
        change: @_onChange
      ).data 'advEditor'

      super()
      
    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      # superclass handles email
      super()

      @model.set 'characters', @_charactersWidget.options.value
      @model.set 'provider', @_providerWidget.val() or null
      if @_passwordChanged
        @model.set 'password', if @model.get('provider')? then undefined else @_passwordWidget.options.value
      @model.set 'isAdmin', @_isAdminCheckbox.is ':checked'
      @model.set 'firstName', @_firstNameWidget.options.value
      @model.set 'lastName', @_lastNameWidget.options.value
      @model.set 'lastConnection', @_lastConnectionWidget.options.value or null
      @model.set 'prefs', JSON.parse @_prefsEditor.options.text

    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>

      # update view title
      @$el.find('> h1').html @_getRenderData().title

      @_passwordChanged = @_tempId?
      @_charactersWidget.setOption 'value', @model.get('characters') or []
      @_providerWidget.val @model.get 'provider'
      @_passwordWidget.setOption 'value', unless @model.get('provider')? then '' else @model.get 'password'
      @_isAdminCheckbox.attr 'checked', @model.get 'isAdmin'
      @_firstNameWidget.setOption 'value', @model.get('firstName') or ''
      @_lastNameWidget.setOption 'value', @model.get('lastName') or ''
      @_lastConnectionWidget.setOption 'value', @model.get 'lastConnection'
      @_prefsEditor.setOption 'text', JSON.stringify @model.get('prefs') or {}

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

      prefs = {}
      try 
        prefs = JSON.parse @_prefsEditor.options.text
      catch err

      comparable.push
        name: 'provider'
        original: @model.get 'provider'
        current: @_providerWidget.val() or null
      ,
        name: 'isAdmin'
        original: @model.get 'isAdmin'
        current: @_isAdminCheckbox.is ':checked'
      ,
        name: 'lastName'
        original: @model.get 'lastName'
        current: @_lastNameWidget.options.value
      ,
        name: 'firstName'
        original: @model.get 'firstName'
        current: @_firstNameWidget.options.value
      ,
        name: 'lastConnection'
        original: @model.get('lastConnection')
        current: @_lastConnectionWidget.options.value or null
      ,
        name: 'characters'
        original: @model.get 'characters'
        current: @_charactersWidget.options.value
      ,
        name: 'prefs'
        original: @model.get 'prefs'
        current: prefs

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

      # adds a validator for password if provider is defined
      @_validators.push new validators.Handler
        handler: (value) => 
          # always allow if provider defined
          return null if @_providerWidget.val() or !@_passwordChanged
          return _.sprintf(i18n.validator.required, i18n.labels.password) if value?.length is 0
          return _.sprintf(i18n.validator.spacesNotAllowed, i18n.labels.password) if value.match /\s/
          null
          
      , i18n.labels.password, @_passwordWidget.element, null, (node) -> node.find('input').val()

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
