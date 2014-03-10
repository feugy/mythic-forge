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
  'model/ClientConf'
  'widget/typeDetails'
  'widget/typeTree'
], ($, Backbone, utils, i18n, i18nEdition, ItemType, EventType, FieldType, Executable, Map, ClientConf) ->

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
  
    ClientConf: -> 
      ClientConf.collection.fetch()

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
        grouped = _(collection.models).groupBy (model) -> model.meta?.category || rootCategory

        # sort categories
        grouped = utils.sortAttributes grouped
        # sort inside categories
        _(grouped).each (content, group) -> grouped[group] = _(content).sortBy (model) -> model.id

        return grouped

      when 'TurnRule' 
        # sort by meta's rank
        return _.chain(collection.models).map((model) -> 
          {criteria:model.meta?.rank, value:model}
        ).sortBy((model) ->
          model.criteria
        ).pluck('value').value()
      else 
        # or sort by id
        return _.sortBy collection.models, 'id'
    
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

      # Executable specificity: do not listen to collection events, but to server events
      @bindTo Executable.collection, 'reset', @_onResetCategory
      @bindTo app.router, 'modelChanged', (operation, model) =>
        return unless utils.isA model, Executable
        @_onUpdateCategory model, Executable.collection, null, operation

      # bind changes to collections
      for model in [ItemType, FieldType, EventType, Map, ClientConf]
        @bindTo model.collection, 'reset', @_onResetCategory

        @bindTo model.collection, 'add', (element, collection) =>
          @_onUpdateCategory element, collection, null, 'add'

        @bindTo model.collection, 'remove', (element, collection) =>
          @_onUpdateCategory element, collection, null, 'remove'

        @bindTo model.collection, 'update', (element, collection, changes) =>
          @_onUpdateCategory element, collection, changes, 'update'

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
        when ClientConf.collection then category = 'ClientConf'
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
            if executable.meta?.kind is 'TurnRule'
              turnRules.push executable
            else if executable.meta?.kind is 'Rule'
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
          category = element.meta?.kind
        when ClientConf.collection 
          if operation isnt 'update' then category = 'ClientConf'
      if category is null and utils.isA element, Executable
        category = element.meta?.kind

      return unless category?

      container = @$el.find "dd[data-category='#{category}']"
      markup = $('<div></div>').typeDetails model:element
      shift = -250
      add = =>
        # gets the list of updated models
        if collection is Executable.collection
          # cast down between turn rules, rules and scripts
          scripts = []
          rules = []
          turnRules = []
          for executable in Executable.collection.models
            if executable.meta?.kind is 'TurnRule'
              turnRules.push executable
            else if executable.meta?.kind is 'Rule'
              rules.push executable
            else
              scripts.push executable
          models = sortCollection 
            models: if element.meta?.kind is 'Rule' then rules else if element.meta?.kind is 'TurnRule' then turnRules else scripts
          , element.meta?.kind
        else 
          models = sortCollection collection

        # compute the insertion index
        if collection is Executable.collection and element.meta?.kind is 'Rule'
          category = element.meta?.category or rootCategory
          idx = models[category].indexOf element
          unless category is rootCategory
            ruleContainer = @$el.find 'dd[data-category="Rule"]'
            container = ruleContainer.find "dt[data-subcategory=#{category}] + dd" 
            if container.length is 0
              # no sub category found: creates it, and insert it at right index
              grouped = sortCollection models: Executable.collection.filter( (rule) -> rule.meta?.kind is 'Rule'), 'Rule'
              # uncategorized is present in grouped but not in rendering, and each category is represented by two nodes 
              containerIdx = (_.indexOf(_.keys(grouped), category)-1)*2
              # and uncategorized rules are displayed above categories
              containerIdx += grouped[rootCategory].length

              subCategory = "<dt data-subcategory=\"#{category}\" class='open'>#{category}</dt><dd></dd>"
              if containerIdx < ruleContainer.children().length
                ruleContainer.children().eq(containerIdx).before subCategory
              else 
                ruleContainer.append subCategory
              container = ruleContainer.find("dt[data-subcategory=\"#{category}\"] + dd")
            else if !container.prev().hasClass 'open'
              # opens the subcategory where rule is inserted
              container.prev().addClass 'open'
              container.show()

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

      remove = => 
        previous = @$el.find(".type-details.#{element.id}").first()
        parent = previous.parent()
        # if the previous value is the only child of a sub-category
        if parent.children().length is 1 && parent.prev().data('subcategory')?
          # removes the whole sub-category
          parent.prev().remove()
          parent.remove()
        else
          # removes only previous value.
          previous.remove()
        
      switch operation
        when 'remove' then remove()
        when 'add' then add()
        when 'update'
          remove()
          add()