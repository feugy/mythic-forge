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
  'backbone'
  'utils/utilities'
  'i18n!nls/common'
  'i18n!nls/edition'
  'model/ItemType'
  'model/EventType'
  'model/FieldType'
  'model/Executable'
  'model/Map'
  'widget/typeDetails'
  'widget/typeTree'
], ($, Backbone, utils, i18n, i18nEdition, ItemType, EventType, FieldType, Executable, Map) ->

  i18n = $.extend true, i18n, i18nEdition

  rootCategory = utils.generateId()

  # loaders for each displayed category
  loaders =
    Map: -> 
      Map.collection.fetch()

    FieldType: -> 
      FieldType.collection.fetch()

    ItemType: -> 
      ItemType.collection.fetch()
    
    EventType: -> 
      EventType.collection.fetch()
  
    Script: -> 
      # open container to allow it to be filled
      $('.explorer dd[data-category="Script"]').show()
      Executable.collection.fetch()

    Rule: ->
      # open container to allow it to be filled
      $('.explorer dd[data-category="Rule"]').show()
      Executable.collection.fetch()
  
    TurnRule: -> 
      # open container to allow it to be filled
      $('.explorer dd[data-category="TurnRule"]').show()
      Executable.collection.fetch()

  # Computes the sort order of a collection.
  # For executable, group by categories.
  #
  # @param collection [Backbone.Collection] the sorted collection
  # @param kind [String] 'Rule', 'TurnRule' or null to specify special behaviour
  # @return a sorted array of models, or an object containing categories and sorted executable inside them
  sortCollection = (collection, kind = null) ->
    switch kind
      when 'Rule'
        # group by category
        grouped = _(collection.models).groupBy (model) -> model.category || rootCategory

        # sort categories
        grouped = utils.sortAttributes grouped
        # sort inside categories
        _(grouped).each (content, group) -> grouped[group] = _(content).sortBy (model) -> model.id
    
        return grouped
      when 'TurnRule' then criteria = 'rank'
      else criteria = 'id'
        
    _.chain(collection.models).map((model) -> 
        {criteria:model[criteria], value:model}
      ).sortBy((model) ->
        model.criteria
      ).pluck('value').value()

  # duration of categories animation, in millis
  animDuration= 250

  # Displays the explorer on edition perspective
  class Explorer extends Backbone.View

    # **private**
    # Timeout to avoid multiple refresh of excutable categories
    _changeTimeout: null

    # **private**
    # Widget that displays item in a tree
    _tree: null

    # The view constructor.
    constructor: () ->
      super tagName: 'div', className:'explorer'

      # bind changes to collections
      for model in [ItemType, FieldType, Executable, EventType, Map]
        @bindTo model.collection, 'reset', @_onResetCategory

        @bindTo model.collection, 'add', (element, collection) =>
          @_onUpdateCategory element, collection, null, 'add'

        @bindTo model.collection, 'remove', (element, collection) =>
          @_onUpdateCategory element, collection, null, 'remove'

        @bindTo model.collection, 'update', (element, collection, changes) =>
          @_onUpdateCategory element, collection, changes, 'update'

      # special case of executable categories that refresh the all tree item
      @bindTo Executable.collection, 'change:category', @_onCategoryChange
      @bindTo Executable.collection, 'change:rank', @_onCategoryChange
      @bindTo Executable.collection, 'change:active', @_onActiveChange

    # The `render()` method is invoked by backbone to display view content at screen.
    render: () =>
      @_tree = @$el.typeTree(
        hideEmpty: false
        openAtStart: false
        animDuration: animDuration
      ).on('open', (event, category) =>
        # avoid multiple loading
        node = @_tree.$el.find("[data-category=#{category}]")
        return if node.hasClass 'loaded'
        node.addClass 'loaded'
        # load the relevant category
        loaders[category]() if category of loaders
      ).on('openElement', (event, details) =>
        app.router.trigger 'open', details.category, details.id
      ).on('removeElement', (event, details) =>
        app.router.trigger 'remove', details.category, details.id
      ).data 'typeTree'
      # for chaining purposes
      @

    # **private**
    # Handler invoked when a category have been retrieved
    # Refresh the corresponding display
    #
    # @param collection [Collection] the refreshed collection.
    _onResetCategory: (collection) =>
      category = null
      switch collection
        when Map.collection then category = 'Map'
        when FieldType.collection then category = 'FieldType'
        when ItemType.collection then category = 'ItemType'
        when EventType.collection then category = 'EventType'
        when Executable.collection
          # Execuables are both used to rule and turn rules. We must distinguish them
          @$el.find("""dd[data-category="Script"], 
            dd[data-category="Rule"], 
            dd[data-category="TurnRule"]""").prev('dt').addClass 'loaded'
          scriptContainer = @$el.find 'dd[data-category="Script"]'
          ruleContainer = @$el.find 'dd[data-category="Rule"]'
          turnRuleContainer = @$el.find 'dd[data-category="TurnRule"]'
          containers = $([scriptContainer[0], ruleContainer[0], turnRuleContainer[0]]).empty()

          # cast down between turn rules and rules
          scripts = []
          rules = []
          turnRules = []
          for executable in Executable.collection.models
            if executable.kind is 'TurnRule'
              turnRules.push executable
            else if executable.kind is 'Rule'
              rules.push executable
            else
              scripts.push executable

          # rules specificity: organize in categories
          grouped = sortCollection models: rules, 'Rule'
          # and then displays
          for category, executables of grouped
            # inside a subcontainer if not in root
            unless category is rootCategory
              ruleContainer.append("<dt data-subcategory=\"#{category}\">#{category}</dt>")
              catContainer = $('<dd></dd>').hide().appendTo ruleContainer
            else 
              catContainer = ruleContainer
            for executable in executables
              catContainer.append $('<div></div>').typeDetails model:executable

          # turn rules are organized by their rank
          turnRules = sortCollection models: turnRules, 'TurnRule'
          turnRuleContainer.append $('<div></div>').typeDetails model:model for model in turnRules
          
          # scripts are organized by their id
          scripts = sortCollection models: scripts, 'Script'
          scriptContainer.append $('<div></div>').typeDetails model:model for model in scripts

      return unless category?

      container = @$el.find("dd[data-category='#{category}']").empty()
      models = sortCollection collection
      container.append $('<div></div>').typeDetails model:model for model in models

    # **private**
    # Handler invoked when a category item have been added or removed
    # Refresh the corresponding display
    #
    # @param element [Object] the category item added or removed
    # @param collection [Collection] the refreshed collection
    # @param changes [Object] map of changed attributes
    # @param operation [String] 'add', 'remove' or 'update' operation
    _onUpdateCategory: (element, collection, changes, operation) =>
      category = null
      switch collection
        when Map.collection 
          if operation isnt 'update' then category = 'Map'
        when FieldType.collection
          if operation isnt 'update' or 'images' of changes then category = 'FieldType'
        when ItemType.collection
          if operation isnt 'update' or 'descImage' of changes then category = 'ItemType'
        when EventType.collection
          if operation isnt 'update' or 'descImage' of changes then category = 'EventType'
        when Executable.collection 
          if operation isnt 'update' then category = (if element.kind then element.kind else 'Script')
      return unless category?

      container = @$el.find "dd[data-category='#{category}']"
      markup = $('<div></div>').typeDetails model:element
      shift = -250
      add = () =>
        # gets the list of updated models
        if collection is Executable.collection
          # cast down between turn rules, rules and scripts
          scripts = []
          rules = []
          turnRules = []
          for executable in Executable.collection.models
            if executable.kind is 'TurnRule'
              turnRules.push executable
            else if executable.kind is 'Rule'
              rules.push executable
            else
              scripts.push executable
          models = sortCollection 
            models: if element.kind is 'Rule' then rules else if element.kind is 'TurnRule' then turnRules else scripts
          , element.kind or 'Script'
        else 
          models = sortCollection collection

        # compute the insertion index
        if collection is Executable.collection and element.kind is 'Rule'
          category = element.category || rootCategory
          container = @$el.find "dt[data-subcategory=#{element.category}] + dd" unless category is rootCategory
          idx = models[category].indexOf element
        else
          idx = models.indexOf element

        markup.css x: shift
        if idx <= 0
          container.prepend markup
        else
          container.children().eq(idx-1).after markup
        # use a small delay to avoid animation while inserting into the DOM
        _.delay => 
          markup.transition x:0, animDuration, -> $(this).css transform: ''
        , 10
        
      switch operation
        when 'remove' then container.find(".#{element.id}").remove()
        when 'add' then add()
        when 'update' 
          container.find(".#{element.id}").remove()
          add()
         
    # **private**
    # Refresh the executable content to displays sub-categories, with small delay to avoid too much refresh
    _onCategoryChange: =>  
      clearTimeout @_changeTimeout if @_changeTimeout
      @_changeTimeout = setTimeout =>
        @_onResetCategory Executable.collection
      , 50

    # **private**
    # Refresh the active status of a rule
    #
    # @param executable [Executable] the concerned executable
    _onActiveChange: (executable) =>  
      return unless executable.kind?
      @$el.find(".#{executable.id}").toggleClass 'inactive', !executable.active