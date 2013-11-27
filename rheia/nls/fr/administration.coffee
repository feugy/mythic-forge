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
  logs:
    dateFormat: 'YY-MM-DD HH:mm:ss'
    nameMaxLength: 15
    levelMaxLength: 5

  titles:
    deployView: 'Client de jeu'
    turnView: 'Passage de tour'
    createVersion: 'Nouvelle version'
    confirmDeploy: 'Déploiement en production'
    deployed: 'Déploiement terminé'
    confirmRestore: 'Confirmation du changement'
    logView: 'Logs serveur'
    timeView: 'Heure du jeu'
    ruleError: 'Erreur de règles'

  labels:
    gameVersions: 'Version en développement'
    deployVersion: 'Déployer en production'
    waitingCommit: 'En attente de confirmation par %s'
    DEPLOY_START: 'début du déploiement...'
    COMPILE_STYLUS: 'compilation Stylus...'
    COMPILE_COFFEE: 'compilation Coffee Script...'
    OPTIMIZE_JS: 'optimisation JavaScript...'
    OPTIMIZE_HTML: 'optimisation Html...'
    DEPLOY_FILES: 'déploiement des fichiers...'
    DEPLOY_END: 'fin du déploiement !'
    COMMIT_START: 'validation du déploiement...'
    COMMIT_END: 'déploiement validé !'
    ROLLBACK_START: 'retour en arrière...'
    ROLLBACK_END: 'déploiement annulé !'
    noRules: 'aucune règle dispo.'
    
  buttons:
    deploy: 'Go !'
    createVersion: 'Créer'
    commit: 'Confirmer'
    rollback: 'Retour en arrière'
    triggerTurn: 'Déclencher le tour'
    pauseTime: 'Arreter'
    playTime: 'Reprendre'
    applyRule: 'Appliquer...'

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
    createVersion: 'Choissisez un nom pour la nouvelle version :'
    confirmRestore: """<p>Vous allez restaurer la version \'%1s\'.</p>
      <p><b>Toute les modifications apportées sur la version courante (%2s) seront perdues.</b></p>
      <p>Voulez-vous vraiment continuer ?</p>"""
    deployed: """<p>Le déployement a réussi !</p>
      <p>Vous pouvez dès à présent tester la nouvelle version.</p>
      <p>Pour terminer le déploiement, vous devez le confirmer ou l'annuler.</p>"""

  errors:
    missingVersion: 'La version est obligatoire'
    versionWithSpace: 'Les espaces sont interdits'
    version: "<p>La récupération ou la création d'une nouvelle version à échouée :</p><p>%s</p>"
    deploy: """<p>Le déployement a échoué :</p>
      <p>%s</p>
      <p>Le client actuellement en production n'a pas été modifié.</p>"""
    resolveRules: """<p>Impossible de résoudre les règles pour %s:</p><p>%s</p>"""
    executeRule: """<p>Impossible d'éxécuter la règle %s sur %s:</p><p>%s</p>"""
