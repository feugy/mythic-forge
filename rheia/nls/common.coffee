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
      fieldAffectation: 'affectField'
      dateFormat: 'YY/MM/DD'
      timeFormat: 'HH:mm:ss'
      dateTimeFormat: 'YY/MM/DD HH:mm:ss'
      instanceAffectation: 'affectInstances'
      uidRegex: /^[\w$-]+$/i
      emailRegex: /^[$_\u0041-\uff70]+$/i

      # map that indicates to which extension corresponds which editor mode
      # extensions are keys, mode are values
      extToMode:
        coffee: 'coffee'
        json: 'json'
        js: 'javascript'
        html: 'html'
        htm: 'html'
        css: 'css'
        xml: 'xml'
        svg: 'svg'
        yaml: 'yaml'
        yml: 'yaml'
        stylus: 'stylus'
        styl: 'stylus'
        png: 'img'
        jpg: 'img'
        jpeg: 'img'
        gif: 'img'
    
    titles:
      serverError: 'Server error'
      loginError: 'Connection error'
      editionPerspective: 'World edition'
      authoringPerspective: 'Game client'
      administrationPerspective: 'Administration tools'
      moderationPerspective: 'World moderation'
      removeConfirm: 'Removal'
      closeConfirm: 'Closure'
      external: 'External modification'
      categories:
        items: 'Objects'
        maps: 'Maps'
        events: 'Events'
        rules: 'Rules'
        turnRules: 'Turn Rules'
        fields: 'Fields'
        players: 'Players'
        scripts: 'Scripts'
        clientConfs: 'Configurations'
      login: 'Rheia - Connection'
        
    labels:
      enterLogin: 'Login: '
      enterPassword: 'Password: '
      connectWith: 'Connect with:'
      orConnect: 'or'
      fieldSeparator: ': '
      deployementInProgress: 'deploying...'
      zoom: 'Zoom'
      gridShown: 'Grid'
      markersShown: 'Markers'
      noX: '~'
      noY: '~'
      noMap: 'none'
      noQuantity: '~'
      noFrom: 'nobody'
      connectedNumber: 'connected'

    buttons:
      close: 'Close'
      create: 'Create'
      login: 'Login'
      google: 'Google'
      twitter: 'Twitter'
      github: 'Github'
      yes: 'Yes'
      no: 'No'
      ok: 'Ok'
      cancel: 'Cancel'
      logout: 'Logout'
      applyRule: 'Apply...'

    validator:
      required: '"%s"\'s value is required'
      spacesNotAllowed: '"%s" cannot contain spaces'
      unmatch: '"%s" does not match expected value'
      invalidHandler: 'invalid value'
      
    tips:
      save: "Saves currently edited tab"
      remove: "Removes currently edited tab"
      item: '<div>Map: %2$s</div><div>X: %3$s</div><div>Y: %4$s</div><div>Quantity: %1$s</div>'
      event: '<div>From: %2$s</div><div>Updated: %1$s</div>'
      player: '<div>%1$s %2$s</div><div>Characters:<ul>%3$s</ul></div>'
      playerCharacter: '<li>%s</li>'

    msgs:
      closeConfirm: "<p>You had modified <b>%s</b>.</p><p>Do you wish to save modifications before closing tab ?</p>"
      externalChange: "<p><b>%s</b> has been modified by another administrator.</p><p>Its values have been updated.</p>"
      externalRemove: "<p><b>%s</b> has been removed by another administratot.</p><p>Tab has been closed.</p>"
      saveFailed: "<p><b>%1s</b> can't be saved on server:</p><p>%2s</p>" 
      removeFailed: "<p><b>%1s</b> can't be removed from server:</p><p>%2s</p>"
      searchFailed: '<p>Search has failed:</p><p>%s</p>'
      powered: 'Powered by <a target="blanck" href="http://github.com/feugy/mythic-forge">Mythic-Forge</a>'
      copyright: '&copy; 2010-2014 Damien Feugas'
      confirmUnload: 'At least one tab from perspective %1s has been modified.'
      invalidId: 'Identifiers can only contain "_", "$", "-" and unaccentuated alphanumerical characters'
      alreadyUsedId: "This identifier is already used by another type, rule, script, configuration, object or event"

    errors:
      wrongCredentials: '<p>Login is unknown or password is errored.</p><p>Please give another try.</p>'
      unauthorized: "<p>You haven't enought right to access to Rheia.</p><p>If you which to became administrator, please contact the game author.</p>"
      expiredToken: '<p>Your session has expired.</p><p>Please connect again.</p>'
      invalidToken: '<p>This session token is invalid.</p><p>Please connect again.</p>'
      disconnected: "<p>Connection to server is lost.</p><p>Please check your network connectivity, and wait a moment: once the server is reachable, you'll be automatically reconnected.</p>"
      kicked: "<p>You've been disconnected from server.</p>"
      deploymentInProgress: '<p>A new version is currently beeing deployed.</p><p>Please wait a moment before connecting again.</p>'
      clientAccessDenied: '<p>You must be identified and have enought right to access to this resource.</p>'

