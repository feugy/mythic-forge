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
      chooseId: "Identifier choice"
      chooseLocale: "Language choice"
      clientConf: 'Client configuration for %s locale'
      eventType: '%s events type'
      fieldType: '%s fields type'
      itemType: '%s objects type'
      map: '%s map'
      multipleAffectation: 'Multiple affectation'
      rule: '%s rule'
      script: '%s script'
      turnRule: '%s turn rule'

    msgs:
      chooseId: "<p>First, you must choose an identifier.</p><p><b>Beware:</b> it must be uniq and cannot be changed in the future.</p>"
      chooseLocale: "<p>First, you must choose a locale (2/4 characters string).</p><p>This locale could be used from the game client.</p>"
      chooseLang: "<p>Then you must choose a programming language, which could not be modified furtherly.</p>"
      externalConfChange: "An external modification has been received and merged"
      invalidConfValues: "JSON syntax error"
      invalidExecutableNameError: "A script/rule identifier can only contain alphanumerical characters"
      multipleAffectation: 'Choose images for this multiple affectation (order is significative)'
      removeClientConfConfirm: "<p>Do you really whish to remove the client configuration for locale <b>%s</b> ?</p><p>Only default locale will be available for requesting clients.<p/>"
      removeEventTypeConfirm: "<p>Do you really whish to remove events type <b>%s</b> ?</p><p>All attached events will be also removed.</p>"
      removeFieldTypeConfirm: "<p>Do you really whish to remove fields type <b>%s</b> ?</p><p>All attached fields will be also removed.</p>"
      removeItemTypeConfirm: "<p>Do you really whish to remove objects type <b>%s</b> ?</p><p>All attached objects will be also removed.</p>"
      removeMapConfirm: "<p>Do you really whish to remove map <b>%s</b> ?</p><p>All attached fields and objects will be also removed.</p>"
      removeRuleConfirm: "<p>Do you really whish to remove rule <b>%s</b> ?</p>"
      removeScriptConfirm: "<p>Do you really whish to remove script <b>%s</b> ?</p>"

    buttons:
      'new': 'New...'
      newClientConf: 'Client configuration'
      newEventType: 'Events type'
      newFieldType: 'Fields type'
      newItemType: 'Objects type'
      newMap: 'Map'
      newRule: 'Rule'
      newScript: 'Script'
      newTurnRule: 'Turn rule'

    labels:
      category: 'Category'
      coffee: 'CoffeeScript'
      descImage: 'Type'
      editedValues: '>>>>>>>>>> Your values:\n'
      id: 'Identifier'
      images: 'Images'
      js: 'JavaScript'
      lang: 'Language'
      locale: 'Locale'
      quantifiable: 'Quantifiable'
      mapKind: 'Kind'
      mapKinds: [
        {name: '2D', value:'square'}
        {name: 'Isometric 3D', value:'diamond'}
        {name: 'Hexagonal', value:'hexagon'}
      ]
      mapNotSaved: 'Please save the map before affecting fields on it'
      newName: 'choose one'
      noRuleCategory: '<i>none</i>'
      properties: 'Property'
      propertyDefaultName: 'ToDo'
      propertyType: 'Type'
      propertyTypes:
        array: 'object array'
        boolean: 'boolean'
        date: 'date'
        float: 'float'
        integer: 'integer'
        json: 'JSON object/array'
        object: 'object'
        string: 'string'
        text: 'text'
      propertyUid: 'Uid (uniq)'
      propertyUidField: 'Uid'
      propertyValue: 'Default value'
      randomAffect: 'random affectation'
      rank: 'Rank'
      remoteValues: "\n<<<<<<<<<< Server's values:\n"
      template: 'Template'
      tileDim: "Tile dimension"

    tips:
      addProperty: 'Adds a new property'
      removeSelection: 'Remove current field selection on the edited map'
      searchTypes: """
          <p>A search request is composed of one or more fields, separated with operators ('or', 'and') and grouped with parenthesis.</p>
          <p>A field is composed of a path and a value, prefixed with "=" or ":" symbol (":" indicates that value is a regular expression).</p>
          <p>Values can be strings (double quotes or simple quotes delimited), numbers or booleans.</p>
          <p>The following search fields are available:</p>
          <ul>
              <li><dfn>id=<var>id</var></dfn> type which id is <var>id</var></li>
              <li><dfn><var>prop</var>=!</dfn> types which has a <var>prop</var> property</li>
              <li><dfn><var>prop</var>=<var>val</var></dfn> types which <var>prop</var> property has value <var>val</var></li>
              <li><dfn>quantifiable=<var>bool</var></dfn> types that are quantifiables or not.</li>
              <li><dfn>category=<var>val</var></dfn> rules which category is <var>val</var></li>
              <li><dfn>rank=<var>val</var></dfn> turn rules which rank is <var>val</var></li>
              <li><dfn>content=<var>val</var></dfn> scripts and rules which content is <var>val</var> (you may use a regular expression)</li>
          </ul>"""
      template: "HTML template to display events. Use \#{X} to include displayed event's X property"