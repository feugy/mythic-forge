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
  logs:
    dateFormat: 'YY-MM-DD HH:mm:ss'
    levelMaxLength: 5
    nameMaxLength: 15

  titles:
    confirmDeploy: 'Déploiement en production'
    confirmRestore: 'Confirmation du changement'
    createVersion: 'Nouvelle version'
    deployed: 'Déploiement terminé'
    deployView: 'Client de jeu'
    logView: 'Logs serveur'
    ruleError: 'Erreur de règles'
    timeView: 'Heure du jeu'
    turnView: 'Passage de tour'

  labels:
    COMMIT_END: 'déploiement validé !'
    COMMIT_START: 'validation du déploiement...'
    COMPILE_COFFEE: 'compilation Coffee Script...'
    COMPILE_STYLUS: 'compilation Stylus...'
    DEPLOY_END: 'fin du déploiement !'
    DEPLOY_FILES: 'déploiement des fichiers...'
    DEPLOY_START: 'début du déploiement...'
    deployVersion: 'Déployer en production'
    gameVersions: 'Version en développement'
    OPTIMIZE_HTML: 'optimisation Html...'
    OPTIMIZE_JS: 'optimisation JavaScript...'
    noRules: 'aucune règle dispo.'
    ROLLBACK_END: 'déploiement annulé !'
    ROLLBACK_START: 'retour en arrière...'
    waitingCommit: 'En attente de confirmation par %s'
    
  buttons:
    commit: 'Confirmer'
    createVersion: 'Créer'
    deploy: 'Go !'
    pauseTime: 'Arreter'
    playTime: 'Reprendre'
    rollback: 'Retour en arrière'
    triggerTurn: 'Déclencher le tour'

  msgs: 
    confirmDeploy: """<p>Vous allez déployer en production le client de jeu actuellement en développement.</p>
      <ol>
        <li>Le client en développement sera compilé et optimisé</li>
        <li>Le client de production sera mis hors ligne, et remplacé</li>
        <li>Vous pourrez tester votre déploiement</li>
        <li>Si vous confirmez, la version sera créee le client remis en ligne</li>
        <li>Dans le cas contraire, la version précédente sera remise en ligne</li>
      </ol>
      <p>Veuillez donner un nom à cette nouvelle version :</p>"""
    confirmRestore: """<p>Vous allez restaurer la version \'%1s\'.</p>
      <p><b>Toute les modifications apportées sur la version courante (%2s) seront perdues.</b></p>
      <p>Voulez-vous vraiment continuer ?</p>"""
    createVersion: 'Choissisez un nom pour la nouvelle version :'
    deployed: """<p>Le déployement a réussi !</p>
      <p>Vous pouvez dès à présent tester la nouvelle version.</p>
      <p>Pour terminer le déploiement, vous devez le confirmer ou l'annuler.</p>"""

  errors:
    deploy: """<p>Le déployement a échoué :</p>
      <p>%s</p>
      <p>Le client actuellement en production n'a pas été modifié.</p>"""
    missingVersion: 'La version est obligatoire'
    version: "<p>La récupération ou la création d'une nouvelle version à échouée :</p><p>%s</p>"
    versionWithSpace: 'Les espaces sont interdits' 