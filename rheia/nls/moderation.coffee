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
    titles:
      copyEvent: 'Event duplication'
      copyItem: 'Object duplication'
      createEvent: 'Event creation'
      createItem: 'Object creation'
      event: '%1$s (%2$s)'
      item: '%1$s (%2$s)'
      player: '%1$s (%2$s)'
      shadowObj: 'Outdated result'

    labels: 
      abscissa: 'X'
      characters: 'Characters'
      creationDate: 'Created on'
      embodiment: 'Embodied'
      email: 'Login'
      from: 'From'
      firstName: 'First name'
      isAdmin: 'Administrator'
      lastConnection: 'Connected on'
      lastName: 'Last name'
      map: 'Map'
      maps: 'Maps'
      newEmail: 'Login/mail'
      noEmbodiment: '~~'
      noMap: 'none'
      noTransition: 'none'
      ordinate: 'Y'
      password: 'Password'
      prefs: 'Settings'
      provider: 'Provider'
      providers: [
        value: null, label: 'Manual'
      ,
        value: 'Github', label: 'Github'
      ,
        value: 'Google', label: 'Google'
      ,
        value: 'Twitter', label: 'Twitter'
      ]
      quantity: 'Quantity'
      updateDate: 'Updated on'
      transition: 'Transition'

    tips:
      connectAs: 'Connect as this player in the game client'
      copy: 'Duplicate existing object or event'
      embody: "Embody this actor to trigger rules from Rheia"
      kick: "Kick player's ass !"
      newEvent: 'Creates a new event'
      newItem: 'Creates a new object'
      newPlayer: 'Creates a new player account'
      searchInstances: """
          <p>A search request is composed of one or more fields, separated with operators ('or', 'and') and grouped with parenthesis.</p>
          <p>A field is composed of a path and a value, prefixed with "=" or ":" symbol (":" indicates that value is a regular expression).</p>
          <p>Values can be strings (double quotes or simple quotes delimited), numbers or booleans.</p>
          <p>The following search fields are available:</p>
          <ul>
              <li><dfn>id=<var>id</var></dfn> objects, events and players which id is <var>id</var></li>
              <li><dfn>type=<var>id</var></dfn> objects and events which type has id <var>id</var></li>
              <li><dfn>type.<var>prop</var>=!</dfn> objects and events which type has a <var>prop</var> property</li>
              <li><dfn>type.<var>prop</var>=<var>val</var></dfn> objects and events which type <var>prop</var> property has value <var>val</var></li>
              <li><dfn>map=!</dfn> objects affected on a map</li>
              <li><dfn>map=<var>id</var></dfn> objects which map has id <var>id</var></li>
              <li><dfn>map.kind=<var>kind</var></dfn> objects which map has kind <var>kind</var></li>
              <li><dfn><var>prop</var>=!</dfn> objects and events which have a <var>prop</var> property</li>
              <li><dfn><var>prop</var>=<var>val</var></dfn> objects and events which <var>prop</var> property has value <var>val</var></li>
              <li><dfn><var>prop</var>.<var>subprop</var>=!</dfn> objects and events which <var>prop</var> property is an object or event which has a <var>subprop</var> property</li>
              <li><dfn><var>prop</var>.<var>subprop</var>=<var>val</var></dfn> objects and events which <var>prop</var> property is an object or event which <var>subprop</var> property has value <var>val</var></li>
              <li><dfn>quantity=<var>qty</var></dfn> quantifiable objects which quantity equals <var>qty</var></li>
              <li><dfn>from=<var>id</var></dfn> events which author has <var>id</var></li>
              <li><dfn>from.<var>prop</var>=!</dfn> events which author has a <var>prop</var> property</li>
              <li><dfn>from.<var>prop</var>=<var>val</var></dfn> events which author <var>prop</var> property has value <var>val</var></li>
              <li><dfn>characters=!</dfn> players that have characters</li>
              <li><dfn>characters=<var>id</var></dfn> players which characters have id <var>id</var></li>
              <li><dfn>characters.<var>prop</var>=!</dfn> players which character has a <var>prop</var> property</li>
              <li><dfn>characters.<var>prop</var>=<var>val</var></dfn> players which character <var>prop</var> property has value <var>val</var></li>
              <li><dfn>provider=<var>val</var></dfn> players which provider (Github, Google...) is <var>val</var></li>
              <li><dfn>firstName=<var>val</var></dfn> players which first name is <var>val</var></li>
              <li><dfn>lastName=<var>val</var></dfn> players which last name is <var>val</var></li>
              <li><dfn>prefs.<var>path</var>=<var>val</var></dfn> players which JSON settings has a <var>path</var> with value <var>val</var></li>
          </ul>"""
          
    msgs:
      chooseEventType: "<p>Please choose a type and an identifier for the created event.</p><p><b>Beware:</b> thoses values cannot be changed in the future.</p>"
      chooseItemType: "<p>Please choose a type and an identifier for the created object.</p><p><b>Beware:</b> thoses values cannot be changed in the future.</p>"
      executeRule: """<p>Cannot execute rule %s on object %s:</p><p>%s</p>"""
      externalChangeEvent: "This event has been externally modified. Its values where updated"
      externalChangeItem: "This object has been externally modified. Its values where updated"
      externalChangePlayer: "This player has been externally modified. Its values where updated"
      invalidEmail: 'Login/email is empty or has invalid characters'
      invalidPrefs: 'Settings: JSON syntax error'
      noEmbodiment: 'To apply rules, you must first embody an object.'
      noTypes: 'No available type. Please create one first in Edition perspective.'
      removeEventConfirm: "<p>Do you really whish to remove event <b>%s</b> ?</p>"
      removeItemConfirm: "<p>Do you really whish to remove object <b>%s</b> ?</p>"
      removePlayerConfirm: "<p>Do you really whish to remove player <b>%s</b> ?</p>"
      resolveRules: """<p>Cannot resolve rules for object %s:</p><p>%s</p>"""
      shadowObj: "<p>This object/event/player does not exist anymore: it has probably removed since your last search.</p><p>Search results where updated consequently.<p/>"