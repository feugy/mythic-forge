###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
    along with Mythic-Forge.  If not, see <http://www.gnu.org/licenses/>.
###
'use strict'

worker = @

# console shim: send message to worker spawner.
self.console = {}
for meth in ['log', 'error']
  ((meth) -> 
    console[meth] = (args...) ->
      worker.postMessage JSON.stringify 
        logMeth: meth
        args: args
  ) meth

importScripts('../lib/require-2.1.9.js');

require.config
  baseUrl: "../"
  paths:
    'coffeescript': 'lib/coffee-script-1.6.3-min'
    'hyperion': 'lib/shim/hyperion'
    'underscore': 'lib/underscore-1.4.3-min'
  shim: 
    'underscore': 
      exports: '_'

require [
  'coffeescript'
], (coffee) ->


  # Compiles and requires the executable content.
  # First, NodeJS requires are transformed into their RequireJS equivalent,
  # then the CoffeeScript code is compiled,
  # and at last the code is executed and required.
  #
  # @param executable [Executable] the compiled executable
  # @param callback [Function] invoked when the executable's content is available.
  # @option callback err [String] error message, or null if no error occured
  # @option callback exported [Object] the executable's content exported object.
  compile = (executable, callback) ->
    # no compilation unless an id was defined
    return callback null unless executable.id?
    # first, uncache the previous executable content.
    require.undef executable.id
    try 
      # then, modifies NodeJS's require into RequireJS dependencies
      content = executable.content

      # Regular expression to extract dependencies from rules
      depReg = /^\s*([^#]\S*)\s*=\s*require[\(\s]([^\s\)]*)[\)\s]?(\S*)\s*$/m

      # gets the required dependencies
      deps = []
      vars = []
      extras = []

      while -1 isnt content.search(depReg)
        # removes the require directive and extract relevant variable and path
        content = content.replace depReg, (str, variable, dep, extra)->
          deps.push dep.replace /^'\.\.\//, "'"
          extra = if extra?.trim().length > 0 then extra.trim() else null 
          vars.push if extra? then "__#{variable}__" else variable
          extras.push extra
          return ''

      # indent all lines
      content = content.split('\n').join '\n  '
      
      # define global variables for export
      extraStr =  ""
      if executable.lang is 'js'
        extraStr += "  var module, exports;\n"
      extraStr += "  module = {exports:{}};\n  exports = module.exports;\n\n"
      for extra, i in extras when extra?
        extraStr += "  #{vars[i].replace(/^__/, '').replace /__$/, ''} = #{vars[i]}#{extra}#{if executable.lang is 'js' then ';\n' else '\n'}"
      
      # and return the exported module
      content += "\n  return module.exports" + (if executable.lang is 'js' then ";" else "")

      if executable.lang is 'coffee'
        # adds the define part and compiles and evaluates the resulting code
        content = "define '#{executable.id}', [#{deps.join ','}], (#{vars.join ','}) ->\n#{extraStr}\n  #{content}"
        start = new Date().getTime()
        content = coffee.compile content
        console.log ">>> native compilation of #{executable.id} in #{new Date().getTime() - start}"
      else
        # adds the define part
        content = "define('#{executable.id}', [#{deps.join ','}], function(#{vars.join ','}){\n#{extraStr}\n  #{content};\n});"

      onError = (err) =>
        # Problème: l'executable en erreur n'est pas forcément le bon
        # TODO delete requirejs.onError
        if added?
          # rule probably depends on another loading executable. retry later
          later.push [executable, callback, err]
          # do not trigger error behaviour
          return executableAdded()

        console.error "w- requirejs error for #{executable.id}: ", err
        executable.error = err
        callback err, null
      requirejs.onError = onError

      # eval resulting code to get the defined object
      eval content

      # require the exported content
      require [executable.id], (exported) => 
        # rule properly compiled
        delete executable.error
        executableAdded() if added?
        callback null, exported
      , onError

    catch exc
      if exc?.location?
        exc.message = "Error on line #{exc.location.first_line + 1}: #{exc.message}"
      console.error "w- compiler error for #{executable.id}: ", exc.message
      callback exc.message, null

  worker.addEventListener 'message', (event) ->
    executable = JSON.parse event.data
    compile executable, (err, exported) ->
      worker.postMessage JSON.stringify id: executable.id, err: err, exported: exported
  , false