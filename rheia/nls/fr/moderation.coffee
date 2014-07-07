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
    item: '%1$s (%2$s)'
    event: '%1$s (%2$s)'
    player: '%1$s (%2$s)'
    createItem: "Création d'un objet"
    createEvent: "Création d'un évènement"
    shadowObj: 'Operation impossible'
    copyItem: "Copie d'un objet"
    copyEvent: "Copie d'un évènement"

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
      value: 'Github', label: 'Github'
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
    noEmbodiment: '~~'
    embodiment: 'Incarné'

  tips:
    connectAs: 'Faites vous passer pour ce joueur dans client de jeu'
    copy: "Duplique l'objet ou l'évènement"
    embody: 'Incarnez cet objet pour lancer des règles depuis Rheia'
    kick: 'Déconnectez le joueur !'
    newItem: 'Créer un nouvel objet'
    newEvent: 'Créer un nouvel évènement'
    newPlayer: 'Créer un nouvel compte joueur'
    searchInstances: """
        <p>Une requête de recherche se compose d'un ou plusieurs champs, séparé par des opérateurs ('or', 'and') et groupé avec des parenthèses.</p>
        <p>Un champ est constitué d'un chemin et d'une valeur, précédée du signe '=' ou ':' (indique que la valeur est une expression régulière).</p>
        <p>Les valeur peuvent être des chaînes de caractères (délimitées par un guillement simple ou double), des nombres, des booléens.</p>
        <p>Les champs de recherche suivants sont disponibles :</p>
        <ul>
            <li><dfn>id=<var>id</var></dfn> objets, évènements et joueurs dont l'id est <var>id</var></li>
            <li><dfn>type=<var>id</var></dfn> objets et évènements dont le type a pour id <var>id</var></li>
            <li><dfn>type.<var>prop</var>='!'</dfn> objets et évènements dont le type possède la propriété <var>prop</var></li>
            <li><dfn>type.<var>prop</var>=<var>val</var></dfn> objets et évènements dont le type possède la propriété <var>prop</var> a la valeur <var>val</var></li>
            <li><dfn>map='!'</dfn> objets ayant une carte</li>
            <li><dfn>map=<var>id</var></dfn> objets sur la carte d'id <var>id</var></li>
            <li><dfn>map.kind=<var>kind</var></dfn> objets sur une carte de type <var>kind</var></li>
            <li><dfn><var>prop</var>='!'</dfn> objets et évènements qui possèdent la propriété <var>prop</var></li>
            <li><dfn><var>prop</var>=<var>val</var></dfn> objets et évènements qui possède la propriété <var>prop</var> a la valeur <var>val</var></li>
            <li><dfn><var>prop</var>.<var>subprop</var>='!'</dfn> objets et évènements dont la propriété <var>prop</var> est un objet ou un évènement qui possède la propriété <var>subprop</var></li>
            <li><dfn><var>prop</var>.<var>subprop</var>=<var>val</var></dfn> objets et évènements dont la propriété <var>prop</var> est un objet ou un évènement qui possède la propriété <var>subprop</var> a la valeur <var>val</var></li>
            <li><dfn>quantity=<var>qty</var></dfn> objets quantifiables dont la quantité est égale à <var>qty</var></li>
            <li><dfn>from=<var>id</var></dfn> évènements dont l'auteur a pour id <var>id</var></li>
            <li><dfn>from.<var>prop</var>='!'</dfn> évènements dont l'auteur possède la propriété <var>prop</var></li>
            <li><dfn>from.<var>prop</var>=<var>val</var></dfn> évènements dont l'auteur possède la propriété <var>prop</var> a la valeur <var>val</var></li>
            <li><dfn>characters='!'</dfn> joueurs qui possèdent des personnages</li>
            <li><dfn>characters=<var>id</var></dfn> joueurs qui possèdent un personnage d'id <var>id</var></li>
            <li><dfn>characters.<var>prop</var>='!'</dfn> joueurs dont un personnage possède la propriété <var>prop</var></li>
            <li><dfn>characters.<var>prop</var>=<var>val</var></dfn> joueurs dont un personnage possède la propriété <var>prop</var> a la valeur <var>val</var></li>
            <li><dfn>provider=<var>val</var></dfn> joueurs dont le fournisseur (Github, Google...) est <var>val</var></li>
            <li><dfn>firstName=<var>val</var></dfn> joueurs dont le prénom est <var>val</var></li>
            <li><dfn>lastName=<var>val</var></dfn> joueurs dont le nom de famille est <var>val</var></li>
            <li><dfn>prefs.<var>path</var>=<var>val</var></dfn> joueurs dont la valeur des préférences JSON pointée par le chemin <var>path</var> a la valeur <var>val</var></li>
       </ul>"""
        
  msgs:
    removeItemConfirm: "<p>Voulez-vous vraiment supprimer l'objet <b>%s</b> ?</p>"
    removeEventConfirm: "<p>Voulez-vous vraiment supprimer l'évènement <b>%s</b> ?</p>"
    removePlayerConfirm: "<p>Voulez-vous vraiment supprimer le joueur <b>%s</b> ?</p>"
    externalChangeItem: "Cet objet à été modifié par ailleurs. Ses valeurs ont été mises à jour"
    externalChangeEvent: "Cet évènement à été modifié par ailleurs. Ses valeurs ont été mises à jour"
    externalChangePlayer: "Ce joueur à été modifié par ailleurs. Ses valeurs ont été mises à jour"
    chooseItemType: "<p>Choisissez un type et un identidiant pour le nouvel objet.</p><p><b>Attention :</b> ses données ne pourront pas être modifiée par la suite.</p>"
    chooseEventType: "<p>Choisissez un type et un identifiant pour le nouvel évènement.</p><p><b>Attention :</b> ses données ne pourront pas être modifiée par la suite.</p>"
    invalidPrefs: 'Préférences : erreur de syntaxe JSON'
    shadowObj: "<p>L'objet en question n'existe plus: il a dû être supprimé depuis votre dernière recherche.</p><p>Votre recherche a été mise à jour.<p/>"
    invalidEmail: 'Le login/e-mail est vide ou contient des caractères invalides'
    noTypes: 'Aucun type disponible. Veuillez en créer un dans la perspective d\'Edition.'
    noEmbodiment: 'Pour appliquer les règles, il faut au préalable incarner un objet de votre choix.'
    resolveRules: """<p>Impossible de résoudre les règles pour %s:</p><p>%s</p>"""
    executeRule: """<p>Impossible d'éxécuter la règle %s sur %s:</p><p>%s</p>"""