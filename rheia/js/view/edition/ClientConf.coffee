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
  'i18n!nls/common'
  'i18n!nls/edition'
  'text!tpl/clientConf.html'
  'view/BaseEditionView'
  'model/ClientConf'
  'widget/advEditor'
], ($, _, i18n, i18nEdition, template, BaseEditionView, ClientConf) ->

  i18n = $.extend true, i18n, i18nEdition

  # Displays and edit a client configuration on edition perspective
  # Triggers the following events:
  # - change: when the model save and remove status changed
  class ClientConfView extends BaseEditionView

    # **private**
    # mustache template rendered
    _template: template

    # **private**
    # models collection on which the view is bound
    _collection: ClientConf.collection

    # **private**
    # removal popup confirmation text, that can take the edited object's name in parameter
    _confirmRemoveMessage: i18n.msgs.removeClientConfConfirm

    # **private**
    # Merge values used when receiving an external modification
    _mergedSource: null

    # **private**
    # Widget to edit configuration values
    _editor: null

    # The view constructor.
    #
    # @param router [Router] the event bus
    # @param id [String] the edited object's id, of null for a creation.
    constructor: (id) ->
      super id, 'client-conf'
      console.log "creates client configuration edition view for #{@model.id}"
      @_mergedSource = null
      # Closes external changes warning after 5 seconds
      @_emptyExternalChange = _.debounce (=> @$el.find('.external-change *').hide 200, -> $(@).remove()), 5000

    # **private**
    # Effectively creates a new model.
    _createNewModel: =>
      @model = new ClientConf()
      @model.source = "example: 'this is an example value'"

    # Indicates wether or not this object can be removed.
    # Default configuration cannot be removed.
    #
    # @return the removable status of this object
    canRemove: => 
      return false if @model.id is 'default'
      super()

    # Called by the TabPerspective each time the view is showned.
    shown: =>
      @_editor?.resize()

    # **private**
    # Prepare data to be rendered into the template
    #
    # @return data filled into the template
    _getRenderData: =>
      # data needed by the template
      title: _.sprintf i18n.titles.clientConf, @model.id
      i18n: i18n

    # **private**
    # Allows subclass to add specific widgets right after the template was rendered and before first 
    # call to `fillRendering`. 
    _specificRender: =>
      @_editor = @$el.find('.source').advEditor(
        mode: 'yaml'
      ).on('change', @_onChange
      ).data 'advEditor'

    # **private**
    # Gets values from rendering and saved them into the edited object.
    _fillModel: =>
      super()
      @model.source = @_editor.options.text
      
    # **private**
    # Updates rendering with values from the edited object.
    _fillRendering: =>
      displayed = if @_mergedSource? then @_mergedSource else @model.source or ""
      @_editor.setOption 'text', displayed
      @_mergedSource = null
      super()

    # **private**
    # Performs view specific save operations, right before saving the model.
    # Adds instance images to pending uploads. 
    #
    # @return optionnal arguments for the `save` Backbone method.
    _specificSave: () =>
      super()
      null

    # **private**
    # Avoid warning popup when edited object have been modified externally, and temorary displays a warning inside tab.
    #
    # @param saved [Object] the received values from server
    _notifyExternalChange: (saved) =>
      @_emptyExternalChange()
      if @$el.find('.external-change *').length is 0
        @$el.find('.external-change').append "<p>#{i18n.msgs.externalConfChange}</p>"

      # merge values if necessary
      return unless @canSave()
      @_mergedSource = i18n.labels.editedValues+@_editor.options.text+i18n.labels.remoteValues+saved.source

    # **private**
    # Returns the list of check fields. This array must contains following structures:
    # - original: the model's original value
    # - current: value form rendering
    # - name: field name, for debug pourposes
    #
    # @return the comparable fields array
    _getComparableFields: =>
      # superclass handles description image
      comparable = super()

      comparable.push
        name: 'source'
        original: @model.source
        current: @_editor.options.text or ""

      comparable