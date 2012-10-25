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
    item: '%1$s (%2$s)'
    event: '%1$s (%2$s)'
    player: '%1$s (%2$s)'
    chooseType: 'Choix du type'

  labels: 
    maps: 'Cartes'
    map: 'Carte'
    abscissa: 'X'
    ordinate: 'Y'
    noMap: 'aucune'
    quantity: 'Quantité'
    from: 'Par'
    creationDate: 'Créé le'
    updateDate: 'Modifié le'
    newEmail: 'Login/E-mail'
    email: 'Login'
    isAdmin: 'Administrateur'
    provider: 'Origine'
    providers: [
      value: 'Google', label: 'Google'
    ,
      value: 'Twitter', label: 'Twitter'
    ,
      value: null, label: 'Manuel'
    ]
    password: 'Mot de passe'
    characters: 'Personnages'
    firstName: 'Prénom'
    lastName: 'Nom'
    lastConnection: 'Connexion le'
    prefs: 'Préférences'
    transition: 'Transition'
    noTransition: 'aucune'

  buttons:
    kick: 'Kickass !'

  tips:
    newItem: 'Créer un nouvel objet'
    newEvent: 'Créer un nouvel évènement'
    newPlayer: 'Créer un nouvel compte joueur'
    searchInstances: """Une requête de recherche se compose d'un ou plusieurs champs, séparé par des opérateur (or, and) et groupé avec des parenthèses.

        Les champs suivants de recherche suivants sont disponibles :
        - `id: *val*` objets, évènements et joueurs par id
        - `*prop*:'!'` objets et évènements possédant la propriété *prop*
        - `*prop*:*val*` objets et évènements dont la propriété *prop* à la valeur *val*
        - `*prop*.*subprop*:'!'` objets et évènements dont la propriété *prop* est un objet ou évènement possède une popriété *subprop*
        - `*prop*.*subprop*:*val*` objets et évènements dont la propriété *prop* est un objet ou évènement dont la popriété *subprop* à la valeur *val*
        - `type:*val*` objets et évènements dont le type à pour id *val*
        - `type.*prop*:'!'` objets et évènements dont le type possède une propriété *prop*
        - `type.*prop*:*val*` objets et évènements dont le type possède une propriété *prop* à la valeur *val*
        - `map:'!'` objets ayant une carte
        - `map:*val*` objets dont la carte à pour id *val*
        - `map.name:*val*` objets dont la carte à pour nom *val* (dépend de la locale courante)
        - `map.kind:*val*` objets dont la carte est de type *val*
        - `quantity:*val*` objets dont la quantité est *val*
        - `from:*val*' évènement dont l'initiateur à pour id *val*
        - `from.*prop*:'!'` évènement dont l'initiateur possède la propriété *prop*
        - `from.*prop*:*val*` évènement dont l'initiateur à la propriété *prop* à la valeur *val*
        - `characters:'!'` joueurs ayant des personnages
        - `characters:*val*` joueurs ayant des personnages d'id *val*
        - `characters.*prop*:'!'` joueur ayant des personnages qui possède la propriété *prop*
        - `characters.*prop*:*val*` joueur ayant des personnages dont la propriété *prop* à la valeur *val*
        - `provider:*val*` joueurs dont le provider est *val*
        - `email:*val*` joueurs dont l'identifiant/email est *val*
        - `firstName:*val*` joueurs dont le prénom est *val*
        - `lastName:*val*` joueurs dont le nom de famille est *val*
        - `prefs.*path*:*val*` joueur dont les préférences dont la valeur pointée par le chemin JSON *path* est *val*
        
        Les valeur peuvent être des chaînes de caractères, des nombres, des booléens ou des expression régulières"""
        
  msgs:
    removeItemConfirm: "<p>Voulez-vous vraiment supprimer l'object <b>%s</b> ?</p>"
    removeEventConfirm: "<p>Voulez-vous vraiment supprimer l'évènement <b>%s</b> ?</p>"
    removePlayerConfirm: "<p>Voulez-vous vraiment supprimer le joueur <b>%s</b> ?</p>"
    itemExternalChange: "L'objet à été modifié par ailleur. Ses valeurs ont été mises à jour"
    eventExternalChange: "L'évènement à été modifié par ailleur. Ses valeurs ont été mises à jour"
    playerExternalChange: "Le joueur à été modifié par ailleur. Ses valeurs ont été mises à jour"
    chooseItemType: "<p>Choisissez un type d'objet pour le nouvel objet :</p>"
    chooseEventType: "<p>Choisissez un type d'objet pour le nouvel évènement :</p>"
    invalidPrefs: 'Préférences : erreur de syntaxe JSON'