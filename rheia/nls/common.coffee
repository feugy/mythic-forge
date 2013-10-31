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
  fr: true
  root: 
    constants:
      fieldAffectation: 'affectField'
      dateFormat: 'YY/MM/DD'
      timeFormat: 'HH:mm:ss'
      dateTimeFormat: 'YY/MM/DD HH:mm:ss'
      instanceAffectation: 'affectInstances'
      uidRegex: /^[\w$-]+$/i #/^[$_\u0041-\uff70].*$/i
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

    msgs: 
      invalidId: 'les identifiant ne peuvent contenir que par des caractères alphanumériques non accentués ainsi que "_", "$" et "-"'
      alreadyUsedId: "cet identifiant est déjà utilisé par un autre type, règle, configuration, objet ou évènement"
    
    TOTRANSLATE: true    

