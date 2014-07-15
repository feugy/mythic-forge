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
    administrationPerspective: "Outils d'administration"
    authoringPerspective: 'Client de jeu'
    categories:
      clientConfs: 'Configurations'
      events: 'Evènements'
      fields: 'Terrains'
      items: 'Objets'
      maps: 'Cartes'
      players: 'Joueurs'
      rules: 'Règles'
      scripts: 'Scripts'
      turnRules: 'Règles de tour'
    closeConfirm: 'Fermeture'
    editionPerspective: 'Edition du monde'
    external: 'Modification externe'
    login: 'Rheia - Connexion'
    loginError: 'Erreur de connexion'
    moderationPerspective: "Modération du monde"
    removeConfirm: 'Suppression'
    restorableFiles: "Fichiers supprimés/déplacés"
    restorableExecutables: "Règles/Scripts supprimés"
    serverError: 'Erreur server'
      
  labels:
    commitDetails: '%3$s: %1$s (%2$s)'
    commitDetailsLast: 'en cours: %1$s'
    connectedNumber: 'connectés'
    connectWith: 'Connectez vous avec :'
    deployementInProgress: 'déploiement...'
    enterLogin: 'Identifiant : '
    enterPassword: 'Mot de passe : '
    fieldSeparator: ' : '
    gridShown: 'Grille'
    history: 'historique'
    markersShown: 'Graduation'
    noFrom: 'personne'
    noMap: 'aucune'
    noQuantity: '~'
    noX: '~'
    noY: '~'
    orConnect: 'ou'
    zoom: 'Zoom'

  buttons:
    applyRule: 'Appliquer...'
    cancel: 'Annuler'
    close: 'Fermer'
    create: 'Créer'
    github: 'Github'
    google: 'Google'
    login: 'Entrer'
    logout: 'Sortir'
    no: 'Non'
    ok: 'Ok'
    twitter: 'Twitter'
    yes: 'Oui'

  validator:
    invalidHandler: 'valeur incorrecte'
    required: 'la valeur de "%s" est requise'
    spacesNotAllowed: '"%s" ne peut pas contenir d\'espaces'
    unmatch: '"%s" ne correspond pas à la valeur attendue'
    
  tips:
    event: '<div>Par : %2$s</div><div>Mise à jour : %1$s</div>'
    item: '<div>Carte : %2$s</div><div>X : %3$s</div><div>Y : %4$s</div><div>Quantité : %1$s</div>'
    player: '<div>%1$s %2$s</div><div>Personnages:<ul>%3$s</ul></div>'
    playerCharacter: '<li>%s</li>'
    remove: "Supprimer l'onglet en cours d'édition"
    restorableExecutables: "Liste les règles ou scripts ayant été supprimés"
    restorableFiles: "Liste les fichiers ayant été supprimés ou déplacés"
    save: "Enregistrer l'onglet en cours d'édition"
    
  msgs:
    alreadyUsedId: "cet identifiant est déjà utilisé par un autre type, règle, configuration, objet ou évènement"
    closeConfirm: "<p>Vous avez modifié <b>%s</b>.</p><p>Voulez-vous sauver les modifications avant de fermer l'onglet ?</p>"
    confirmUnload: 'Au moins une vue de la perspective %1s à été modifiée.'
    externalChange: "<b>%s</b> a été modifié par ailleurs. Ses valeurs ont été mises à jour"
    externalRemove: "<p><b>%s</b> a été supprimé par un autre administrateur.</p><p>L'onglet a été fermé.</p>"
    invalidId: 'les identifiant ne peuvent contenir que par des caractères alphanumériques non accentués ainsi que "_", "$" et "-"'
    noRestorableExecutables: "<p>Il n'y a pas de règles/scripts à restaurer.</p>"
    noRestorableFiles: "<p>Il n'y a pas de fichiers à restaurer.</p>"
    removeFailed: "<p><b>%1s</b> n'a pas pû être supprimé du serveur :</p><p>%2s</p>"
    restorableExecutables: "<p>Voici la liste des règles/scripts supprimés.</p><p>Cliquez sur celui de votre choix pour visualiser son contenu, mais il faudra le sauvegarder pour le restraurer définitivement.</p>"
    restorableFiles: "<p>Voici la liste des fichiers supprimés ou déplacés.</p><p>Cliquez sur un fichier pour visualiser son contenu, mais il faudra le sauvegarder pour le restraurer définitivement.</p>"
    saveFailed: "<p><b>%1s</b> n'a pas pû être sauvé sur le serveur :</p><p>%2s</p>" 
    searchFailed: 'La recherche à échouée :<br/><br/>%s'
 
  errors:
    clientAccessDenied: '<p>Vous devez être authentifié et disposer des droits suffisants pour accéder à cette resource.</p>'
    deploymentInProgress: '<p>Une version est en cours de déploiement.</p><p>Veuillez patienter quelques instants avant de vous reconnecter.</p>'
    disconnected: '<p>La connexion avec le serveur est perdue.</p><p>Veuillez vérifier votre connexion internet, et attendre quelques instants : dès que le serveur sera joignable, vous serez automatiquement reconnecté.</p>'
    expiredToken: '<p>Votre session a expirée.</p><p>Veuillez vous reconnecter.</p>'
    invalidToken: '<p>Ce jeton de session est invalide.</p><p>Veuillez vous reconnecter.</p>'
    kicked: '<p>Vous avez été déconnecté du serveur.</p>'
    unauthorized: "<p>Vous n'avez pas les droits nécessaires pour accéder à Rheia.</p><p>Si vous souhaitez devenir administrateur, merci de contacter l'auteur du jeu.</p>"
    wrongCredentials: '<p>Le login est inconnu ou le mot de passe érroné.</p><p>Veuillez rééssayer.</p>'