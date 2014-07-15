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
    constants:
      dateFormat: 'YY/MM/DD'
      dateTimeFormat: 'YY/MM/DD HH:mm:ss'
      defaultFileFilter: '-jpg,jpeg,png,gif'
      fieldAffectation: 'affectField'
      instanceAffectation: 'affectInstances'
      emailRegex: /^[$_\u0041-\uff70]+$/i
      # map that indicates to which extension corresponds which editor mode
      # extensions are keys, mode are values
      extToMode:
        coffee: 'coffee'
        css: 'css'
        gif: 'img'
        html: 'html'
        htm: 'html'
        jpg: 'img'
        jpeg: 'img'
        json: 'json'
        js: 'javascript'
        png: 'img'
        stylus: 'stylus'
        styl: 'stylus'
        svg: 'svg'
        xml: 'xml'
        yaml: 'yaml'
        yml: 'yaml'
      timeFormat: 'HH:mm:ss'
      uidRegex: /^[\w$-]+$/i
    
    titles:
      administrationPerspective: 'Administration tools'
      authoringPerspective: 'Game client'
      categories:
        clientConfs: 'Configurations'
        events: 'Events'
        fields: 'Fields'
        items: 'Objects'
        maps: 'Maps'
        players: 'Players'
        rules: 'Rules'
        scripts: 'Scripts'
        turnRules: 'Turn Rules'
      closeConfirm: 'Closure'
      editionPerspective: 'World edition'
      external: 'External modification'
      login: 'Rheia - Connection'
      loginError: 'Connection error'
      moderationPerspective: 'World moderation'
      removeConfirm: 'Removal'
      restorableFiles: "Restorable files"
      restorableExecutables: "Restorable rules/scripts"
      serverError: 'Server error'
        
    labels:
      commitDetails: '%3$s: %1$s (%2$s)'
      commitDetailsLast: 'current: %1$s'
      connectedNumber: 'connected'
      connectWith: 'Connect with:'
      deployementInProgress: 'deploying...'
      enterLogin: 'Login: '
      enterPassword: 'Password: '
      fieldSeparator: ': '
      gridShown: 'Grid'
      history: 'history'
      markersShown: 'Markers'
      noFrom: 'nobody'
      noMap: 'none'
      noQuantity: '~'
      noX: '~'
      noY: '~'
      orConnect: 'or'
      zoom: 'Zoom'

    buttons:
      applyRule: 'Apply...'
      cancel: 'Cancel'
      close: 'Close'
      create: 'Create'
      github: 'Github'
      google: 'Google'
      login: 'Login'
      logout: 'Logout'
      no: 'No'
      ok: 'Ok'
      twitter: 'Twitter'
      yes: 'Yes'

    validator:
      invalidHandler: 'invalid value'
      required: '"%s"\'s value is required'
      spacesNotAllowed: '"%s" cannot contain spaces'
      unmatch: '"%s" does not match expected value'
      
    tips:
      event: '<div>From: %2$s</div><div>Updated: %1$s</div>'
      item: '<div>Map: %2$s</div><div>X: %3$s</div><div>Y: %4$s</div><div>Quantity: %1$s</div>'
      player: '<div>%1$s %2$s</div><div>Characters:<ul>%3$s</ul></div>'
      playerCharacter: '<li>%s</li>'
      remove: "Removes currently edited tab"
      restorableFiles: "Displays list of removed/renamed files"
      restorableExecutables: "Displays list of removed rules or scripts"
      save: "Saves currently edited tab"

    msgs:
      alreadyUsedId: "This identifier is already used by another type, rule, script, configuration, object or event"
      closeConfirm: "<p>You had modified <b>%s</b>.</p><p>Do you wish to save modifications before closing tab ?</p>"
      confirmUnload: 'At least one tab from perspective %1s has been modified.'
      copyright: '&copy; 2010-2014 Damien Feugas'
      externalChange: "<b>%s</b> has been externally modified. Its values have been updated"
      externalRemove: "<p><b>%s</b> has been removed by another administratot.</p><p>Tab has been closed.</p>"
      invalidId: 'Identifiers can only contain "_", "$", "-" and unaccentuated alphanumerical characters'
      noRestorableExecutables: "<p>No rules/scripts to restore.</p>"
      noRestorableFiles: "<p>No files to restore.</p>"
      powered: 'Rheia, powering <a target="blanck" href="http://github.com/feugy/mythic-forge">Mythic-Forge</a>'
      removeFailed: "<p><b>%1s</b> can't be removed from server:</p><p>%2s</p>"
      restorableFiles: "<p>This is the whole list of removed/renamed files.</p><p>Click on one file to get its content, and then save it to restore it.</p>"
      restorableExecutables: "<p>This is the whole list of removed rules or scripts.</p><p>Click on one file to get its content, and then save it to restore it.</p>"
      saveFailed: "<p><b>%1s</b> can't be saved on server:</p><p>%2s</p>" 
      searchFailed: '<p>Search has failed:</p><p>%s</p>'
      
    errors:
      clientAccessDenied: '<p>You must be identified and have enought right to access to this resource.</p>'
      deploymentInProgress: '<p>A new version is currently beeing deployed.</p><p>Please wait a moment before connecting again.</p>'
      disconnected: "<p>Connection to server is lost.</p><p>Please check your network connectivity, and wait a moment: once the server is reachable, you'll be automatically reconnected.</p>"
      expiredToken: '<p>Your session has expired.</p><p>Please connect again.</p>'
      invalidToken: '<p>This session token is invalid.</p><p>Please connect again.</p>'
      kicked: "<p>You've been disconnected from server.</p>"
      unauthorized: "<p>You haven't enought right to access to Rheia.</p><p>If you which to became administrator, please contact the game author.</p>"
      wrongCredentials: '<p>Login is unknown or password is errored.</p><p>Please give another try.</p>'