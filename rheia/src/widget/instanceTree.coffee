###
  Copyright 2010~2014 Damien Feugas

    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http:#www.gnu.org/licenses/>.
###
'use strict'

define [
  'jquery'
  'utils/utilities'
  'i18n!nls/common'
  'widget/typeTree'
  'widget/instanceDetails'
], ($, utils, i18n, TypeTree) ->

  # A tree that displays instances models.
  # Organize models in categories.
  # Triggers `open` event when opening a category (with category in parameter)
  # Triggers `openElement` event when clicking an item, or its open contextual menu item (with category and id in parameter)
  # Triggers `removeElement` event when clicking an item remove contextual menu item (with category and id in parameter)
  class InstanceTree extends TypeTree

    # Builds rendering
    constructor: (element, options) ->
      # list of displayed categories
      @_categories = [
        name: i18n.titles.categories.players
        id: 'Player'
      ,
        name: i18n.titles.categories.items
        id: 'Item'
      ,
        name: i18n.titles.categories.events
        id: 'Event'
      ]

      super element, options
      @$el.addClass('instance-tree')
    
    # **private**
    # Render models of a single category. 
    #
    # @param content [Array] models contained in a given category
    # @param container [Object] DOM node that will display the category content
    # @param category [String] the displayed category id
    _renderModels: (content, container, category) =>
      for model in content
        $('<div></div>').instanceDetails(
          value: model
          dndType: @options.dndType
          tooltipFct: @options.tooltipFct
          noUpdate: true
        ).appendTo(container)
        .data('id', model.id)
        .data 'category', category

  # widget declaration
  InstanceTree._declareWidget 'instanceTree', $.extend true, {}, $.fn.typeTree.defaults, 

    # Tooltip generator used. 
    # This function takes displayed object as parameter, and must return a string, used as tooltip.
    # If null is returned, no tooltip displayed
    tooltipFct: null
    
    # Used scope for instance drag'n drop operations. Null to disable drop outside widget
    dndType: null