###
  Copyright 2010~2014 Damien Feugas
  
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
  'view/TabPerspective'
  'i18n!nls/common'
], ($, _, moment, TabPerspective, i18n) ->

  # The versionned perspective manage different version of handled objects
  class VerionnedPerspective extends TabPerspective

    # **private**
    # Selector that displays current object history list.
    _historyList: null

    # **private**
    # Suffix used to get i18n labels, titles and messages
    _i18nSuffix: ''

    # **private**
    # Restorable collection
    _restorableCollection: null

    # The view constructor.
    #
    # @param name [String] perspective name
    # @param suffix [String] suffix used to get i18n labels, titles and messages
    # @param collection [Backbone.Collection] collection from which models are restored
    constructor: (name, suffix, collection) ->
      super name
      @_i18nSuffix = suffix
      @_restorableCollection = collection

      # removes history update handler
      @bindTo @_restorableCollection, 'remove', (item) => 
        item.off 'history', @_onUpdateHistory

    # The `render()` method is invoked by backbone to display view content at screen.
    # oInstanciate bar buttons.
    render: =>
      super()
      # update button bar on tab change, but after a slight delay to allow internal update when 
      # tab is removed
      @_tabs.element.on 'tabsselect tabsadd tabsremove', => _.defer => @_onUpdateBar true

      # get the history selector
      @_historyList = @$el.find '.history select'
      @_historyList.on 'change', @_onRequireVersion

      # for chaining purposes
      return @

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
      view = _.find @_views, (view) => id is @_domId view

      # bind changes to update tab
      view.on 'change', => @_onUpdateBar false
      view.model.on 'history', @_onUpdateHistory

    # **private**
    # Current edited object change handler: updates the button bar consequently, with history selector.
    #
    # @param withHistory [Boolean] true to retrieve file history. Default to false
    _onUpdateBar: (withHistory = false)=>
      view = @_views?[@_tabs.options.selected]
      # no view selected (after a deletion for example)
      unless view? and view?.model?.constructor?.collection is @_restorableCollection
        @_historyList.attr 'disabled', 'disabled'
        @_historyList.empty()
        return null

      if withHistory is true
        @_historyList.removeAttr('disabled').empty()
        # history already fetched
        if view.model.history?
          @_onUpdateHistory view.model 
        else
          view.model.fetchHistory()

      view

    # **private**
    # Model history retrieval handler. If file is still displayed as first tab, update the selector content.
    #
    # @param model [model] the model for which history have been retrieved
    _onUpdateHistory: (model) =>
      # no view displayed
      return if @_tabs.options.selected is -1
      displayed = @_views[@_tabs.options.selected]?.model
      # not the current file
      return unless displayed?.equals model
      # cleans an redraw history selector content
      @_historyList.empty()
      html = ""
      for commit in model.history
        date = moment(commit.date).format i18n.constants.dateTimeFormat
        console.log commit
        message = _.sprintf (if commit.id then i18n.labels.commitDetails else i18n.labels.commitDetailsLast), date, commit.author, commit.message
        html += "<option value='#{commit.id}'>#{message}</option>" 
      @_historyList.append html

    # **private**
    # File history change handler. Immediately ask versionned content to server.
    _onRequireVersion: =>
      return if @_tabs.options.selected is -1
      version = @_historyList.find(':selected').val()
      # do not proceed if no version specified
      item = @_views[@_tabs.options.selected]?.model
      item?.fetchVersion version

    # **private**
    # Display list of restorable files inside a popup
    #
    # @param restorables [Array] array of restorables files (may be empty)
    _onDisplayRestorables: (restorables) =>
      return if $('#restorablesPopup').length isnt 0

      message = i18n.msgs[if restorables.length is 0 then "noRestorable#{@_i18nSuffix}" else "restorable#{@_i18nSuffix}"]
      # displays a popup
      html = """<div id='restorablesPopup' title='#{i18n.titles["restorable#{@_i18nSuffix}"].replace /'/g, '&apos;'}'>#{message}"""

      if restorables.length
        idAttribute = @_restorableCollection.model::idAttribute
        html += '<ul>'
        html += "<li>#{restorable.item[idAttribute]}</li>" for restorable in restorables
        html += '</ul>'

      html += '</div>'

      buttonSpec = [
        text: i18n.buttons.close
        icons:
          primary: 'ui-icon small valid'
        click: -> $('#restorablesPopup').remove()
      ]

      $(html).dialog(
        modal: false
        close: (event) -> buttonSpec[0].click()
        buttons: buttonSpec
      ).on 'click', 'li', (event) =>
        # restore file.
        idx = $(event.target).closest('li').index()
        return if -1 is idx
        item = restorables[idx].item

        # add item to collection to allow opening
        item.restored = true
        @_restorableCollection.add item, silent: true

        # when version will be loaded, opens the file
        opening = (fetched, content) =>
          item.content = content
          kind = item?.meta?.kind or @_restorableCollection.model::_className
          @_onOpenElement kind, item[@_restorableCollection.model::idAttribute]

          # remove item from collection to allow further save
          item.off 'version', opening
          @_restorableCollection.remove item, silent: true

        item.on 'version', opening

        # load file content, with special git trick: we need to refer to the parent commit of the
        # deleting commit.
        item.fetchVersion "#{restorables[idx].id}~1"