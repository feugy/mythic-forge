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
    logs:
      dateFormat: 'DD-MM-YY HH:mm:ss'
      levelMaxLength: 5
      nameMaxLength: 15

    titles:
      confirmDeploy: 'Production deployment'
      confirmRestore: 'Restore confirmation'
      createVersion: 'New version'
      deployed: 'Finished deployment'
      deployView: 'Game client'
      logView: 'Server logs'
      ruleError: 'Rule error'
      timeView: 'Game time'
      turnView: 'Turn'

    labels:
      COMPILE_COFFEE: 'CoffeeScript compilation...'
      COMPILE_STYLUS: 'Stylus compilation...'
      COMMIT_END: 'déployment commited !'
      COMMIT_START: 'commiting deployment...'
      DEPLOY_END: 'deployment ended !'
      DEPLOY_START: 'deployment started...'
      deployVersion: 'Deploy in production'
      gameVersions: 'Development version'
      noRules: 'no available rule'
      OPTIMIZE_HTML: 'Html optimization...'
      OPTIMIZE_JS: 'JavaScript optimization...'
      ROLLBACK_END: 'deployment rollbacked !'
      ROLLBACK_START: 'starting rollback...'
      waitingCommit: 'Waiting confirmation from %s'
      
    buttons:
      commit: 'Commit'
      createVersion: 'Create'
      deploy: 'Go !'
      pauseTime: 'Pause'
      playTime: 'Resume'
      triggerTurn: 'Trigger turn'
      rollback: 'Rollback'

    msgs: 
      confirmDeploy: """<p>You're about to deploy devlopment game client to production.</p>
        <ol>
          <li>Development client will be compiled and optimized</li>
          <li>Production client will be offlined and replaced</li>
          <li>You'll have tome to check the deployed version</li>
          <li>If you commit it, the deployed version will became production version and onlined</li>
          <li>If you rollback it, previous production version will be restored and onlined</li>
        </ol>
        <p>Please name the deployed version:</p>"""
      confirmRestore: """<p>You're about to restore version \'%1s\'.</p>
        <p><b>All modification from development version (%2s) will be lost.</b></p>
        <p>Do you really wish to proceed ?</p>"""
      createVersion: 'Choose a name for the new version:'
      deployed: """<p>Deployment has succeeded !</p>
        <p>From now, you can check the deployed version.</p>
        <p>To end the deployment, you must commit or rollback it.</p>"""

    errors:
      deploy: """<p>Deployment has failed:</p>
        <p>%s</p>
        <p>Game client currently in production was not modified.</p>"""
      missingVersion: 'Version is required'
      version: "<p>Restoration or creation of a new version failed:</p><p>%s</p>"
      versionWithSpace: 'Spaces are not allowed'