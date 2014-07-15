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
  titles:
    chooseId: "Choix d'un identifiant"
    chooseLocale: "Choix d'une langue"
    clientConf: 'Configuration cliente, langue %s'
    eventType: "Type d'évènements %s"
    fieldType: 'Type de terrains %s'
    itemType: "Type d'objets %s"
    map: 'Carte %s'
    multipleAffectation: 'Affectation multiple'
    rule: 'Règle %s'
    script: 'Script %s'
    turnRule: 'Règle de tour %s'

  msgs:
    chooseId: "<p>Vous devez d'abord choisir un identifiant.</p><p><b>Attention :</b> il doit être unique et ne pourra être modifié par la suite.</p>"
    chooseLocale: "<p>Vous devez d'abord choisir une langue (code sur 2 ou 4 caractères).</p><p>Cette langue pourra être utilisée depuis le client de jeu.</p>"
    chooseLang: "<p>Vous devez également choisir un langage de programmation, qui ne pourra pas être modifié par la suite.</p>"
    externalConfChange: "Une modification externe à été reçue et fusionné"
    invalidConfValues: "Erreur de syntaxe JSON"
    invalidExecutableNameError: "l'identifiant d'un script/règle ne peut contenir que des caractères alphanumeriques"
    multipleAffectation: 'Choisisez les images que vous aller affecter dans la séléction (l\'ordre est significatif)'
    removeClientConfConfirm: "<p>Voulez-vous vraiment supprimer la configuration pour la langue <b>%s</b> ?</p><p>Seuls les valeurs de la langue par défaut s'appliqueront.<p/>"
    removeEventTypeConfirm: "<p>Voulez-vous vraiment supprimer le type d'évènements <b>%s</b> ?</p><p>Tous les évènements de ce type seront aussi supprimés.</p>"
    removeFieldTypeConfirm: "<p>Voulez-vous vraiment supprimer le type de terrains <b>%s</b> ?</p><p>Tous les terrains de ce type seront aussi supprimés.</p>"
    removeItemTypeConfirm: "<p>Voulez-vous vraiment supprimer le type d'object <b>%s</b> ?</p><p>Tous les objets de ce type seront aussi supprimés.</p>"
    removeMapConfirm: "<p>Voulez-vous vraiment supprimer la carte <b>%s</b> ?</p><p>Tous les terrains et les objets sur cette carte seront aussi supprimés.</p>"
    removeRuleConfirm: "<p>Voulez-vous vraiment supprimer la règle <b>%s</b> ?</p>"
    removeScriptConfirm: "<p>Voulez-vous vraiment supprimer le script <b>%s</b> ?</p>"
    
  buttons:
    'new': 'Nouveau...'
    newClientConf: "Configuration cliente"
    newEventType: "Type d'évènements"
    newFieldType: 'Type de terrains'
    newItemType: "Type d'objets"
    newMap: 'Carte'
    newRule: 'Règle'
    newScript: 'Script'
    newTurnRule: 'Règle de tour'
    
  labels:
    category: 'Catégorie'
    coffee: 'CoffeeScript'
    descImage: 'Type'
    editedValues: '>>>>>>>>>> Vos valeurs:\n'
    id: 'Identifiant'
    images: 'Images'
    js: 'JavaScript'
    lang: 'Langage'
    locale: 'Langue'
    quantifiable: 'Quantifiable'
    mapKind: 'Type'
    mapKinds: [
      {name: '2D', value:'square'}
      {name: '3D isométrique', value:'diamond'}
      {name: 'Hexagonale', value:'hexagon'}
    ]
    mapNotSaved: "Merci de sauvegarder la carte avant d'affecter des terrains"
    newName: 'A remplir'
    noRuleCategory: '<i>aucune</i>'
    properties: 'Propriétés'
    propertyDefaultName: 'todo'
    propertyType: 'Type'
    propertyTypes:
      array: "tableau d'objets"
      boolean: 'booléen'
      date: 'date'
      integer: 'entier'
      json: "objet/tableau Json"
      float: 'réel'
      object: 'objet'
      string: 'chaîne de caractères'
      text: 'texte'
    propertyUid: 'Uid (unique)'
    propertyUidField: 'Uid'
    propertyValue: 'Valeur par défaut'
    randomAffect: 'affectation aléatoire'
    rank: 'Rang'
    remoteValues: '\n<<<<<<<<<< Valeurs du serveur:\n'
    template: 'Template'
    tileDim: "Dimension d'une tuile"

  tips:
    addProperty: 'Ajoute une nouvelle propriété'
    removeSelection: 'Supprime la séléction courante de la carte éditée'
    searchTypes: """
        <p>Une requête de recherche se compose d'un ou plusieurs champs, séparé par des opérateurs ('or', 'and') et groupé avec des parenthèses.</p>
        <p>Un champ est constitué d'un chemin et d'une valeur, précédée du signe '=' ou ':' (indique que la valeur est une expression régulière).</p>
        <p>Les valeur peuvent être des chaînes de caractères (délimitées par un guillement simple ou double), des nombres, des booléens.</p>
        <p>Les champs de recherche suivants sont disponibles :</p>
        <ul>
            <li><dfn>id=<var>id</var></dfn> types dont l'id est <var>id</var></li>
            <li><dfn><var>prop</var>=!</dfn> types qui possèdent la propriété <var>prop</var></li>
            <li><dfn><var>prop</var>=<var>val</var></dfn> types dont la propriété <var>prop</var> a la valeur <var>val</var></li>
            <li><dfn>quantifiable=<var>bool</var></dfn> types quantifiables ou non.</li>
            <li><dfn>category=<var>val</var></dfn> règles dont la catégorie est <var>val</var></li>
            <li><dfn>rank=<var>val</var></dfn> règles de tour de rang <var>val</var></li>
            <li><dfn>content=<var>val</var></dfn> règles et scripts dont le contenu est <var>val</var> (utilisez une expression régulière)</li>
        </ul>"""
    template: "Template HTML d'affichage des évènements. Utilisez \#{X} pour inclure la propriété X de l'évènement affiché"