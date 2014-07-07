###
  Copyright 2010~2014 Damien Feugas
  
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

define
  fr: true
  root: 
    loadableImage:
      noImage: 'No image'

    search:
      noResults: 'Empty results'
      oneResult: '1 result'
      nbResults: '%d results'

    spriteImage:
      dimensions: 'w x h '
      sprites: 'Sprites:'
      rank: 'Rank'
      name: 'Name'
      number: 'Number'
      duration: 'Duration'
      add: 'Add'
      newName: 'sprite'
      unsavedSprite: 'Sprite name "%s" is already used, please choose another one'

    property:
      isNull: 'null'
      isTrue: 'true'
      isFalse: 'false'
      objectTypes: [{
        val:'Any'
        name:"objects/events"
      },{
        val:'Item'
        name:'objects'
      },{
        val:'Event'
        name:'events'
      }]

    instanceDetails:
      name: '%1$s <i>(%2$s)</i>'
      open: 'Open "%s"'
      remove: 'Remove "%s"'

    typeDetails:
      open: 'Open "%s"'
      remove: 'Remove "%s"'
      
    instanceList: 
      empty: "affect an object by drag'n drop"
      unbind: "unlink object/event"

    authoringMap:
      tipPos: "x: %s y: %s"
      tipObj: "%s (#%s)"

    advEditor:
      find: 'Search:'
      replaceBy: 'Replace with:'
      findPrev: 'previous result'
      findNext: 'next result'
      replace: 'replace first result'
      replaceAll: 'replace all results'