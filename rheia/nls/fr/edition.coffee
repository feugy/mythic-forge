###
  Copyright 2010,2011,2012 Damien Feugas
  
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
    itemType: "Type d'objets %s"
    eventType: "Type d'évènements %s"
    fieldType: 'Type de terrains %s'
    rule: 'Règle'
    turnRule: 'Règle de tour'
    map: 'Carte %s'
    multipleAffectation: 'Affectation multiple'

  msgs:
    removeItemTypeConfirm: "<p>Voulez-vous vraiment supprimer le type d'object <b>%s</b> ?</p><p>Tous les objets de ce type seront aussi supprimés.</p>"
    removeEventTypeConfirm: "<p>Voulez-vous vraiment supprimer le type d'évènements <b>%s</b> ?</p><p>Tous les évènements de ce type seront aussi supprimés.</p>"
    removeFieldTypeConfirm: "<p>Voulez-vous vraiment supprimer le type de terrains <b>%s</b> ?</p><p>Tous les terrains de ce type seront aussi supprimés.</p>"
    removeRuleConfirm: "<p>Voulez-vous vraiment supprimer la règle <b>%s</b> ?</p>"
    removeMapConfirm: "<p>Voulez-vous vraiment supprimer la carte <b>%s</b> ?</p><p>Tous les terrains et les objets sur cette carte seront aussi supprimés.</p>"
    invalidUidError: 'les uid de propriétés ne peuvent commencer que par des caractères alphabétiques ou $ et _'
    invalidExecutableNameError: "l'identifiant d'un executable ne peut contenir que des caractères alphanumeriques"
    multipleAffectation: 'Choisisez les images que vous aller affecter dans la séléction (l\'ordre est significatif)'

  buttons:
    'new': 'Nouveau...'
    newItemType: "Type d'objets"
    newFieldType: 'Type de terrains'
    newRule: 'Règle'
    newTurnRule: 'Règle de tour'
    newMap: 'Carte'
    newEventType: "Type d'évènements"

  labels:
    id: 'Identifiant'
    descImage: 'Type'
    images: 'Instances'
    category: 'Catégorie'
    rank: 'Rang'
    name: 'Nom'
    desc: 'Description'
    newName: 'A remplir'
    quantifiable: 'Quantifiable'
    noRuleCategory: 'aucune'
    propertyUidField: 'Uid'
    properties: 'Propriétés'
    propertyUid: 'Uid (unique)'
    propertyType: 'Type'
    propertyValue: 'Valeur par défaut'
    propertyDefaultName: 'todo'
    propertyTypes:
      string: 'chaîne de caractères'
      text: 'texte'
      boolean: 'booléen'
      float: 'réel'
      integer: 'entier'
      date: 'date'
      object: 'objet'
      array: "tableau d'objets"
    mapKind: 'Type'
    mapKinds: [
      {name: 'Hexagonale', value:'hexagon'}
      {name: '3D isométrique', value:'diamond'}
      {name: '2D', value:'square'}
    ]
    randomAffect: 'affectation aléatoire'

  tips:
    addProperty: 'Ajoute une nouvelle propriété'
    removeSelection: 'Supprime la séléction courante de la carte éditée'
    description: 'TODO description'
    searchTypes: """Une requête de recherche se compose d'un ou plusieurs champs, séparé par des opérateur (or, and) et groupé avec des parenthèses.

        Les champs suivants de recherche suivants sont disponibles :
        - `id: *val*` tous types par id
        - `name: *val*` tous types par nom (dépend de la locale courante)
        - `desc: *val*` types d'objets, évènements et terrains par description (dépend de la locale courante)
        - `*prop*: '!'` types d'objets et d'évènements possédant la propriété *prop*
        - `*prop*: *val*` types d'objets et d'évènements dont la propriété *prop* à la valeur *val* par défaut
        - `quantifiable: *val*` types d'objet quantifiables ou non
        - `category: *val*` règle par catégorie
        - `rank: *val*` règles de tour par ordre
        - `content: *val*` règles et règles de tour par contenu
        
        Les valeur peuvent être des chaînes de caractères, des nombres, des booléens ou des expression régulières"""