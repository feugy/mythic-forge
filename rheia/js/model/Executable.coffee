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

define [
  'model/BaseModel'
  'coffeescript'
  'utils/utilities'
  'model/TurnRule'
  'model/Rule'
], (Base, coffee, utils, TurnRule, Rule) ->

  # To handle inter-dependencies between executables, store the number
  # of added executable at the same time
  added = null
  lastAdded = null

  # Store arguments of compile method for each failing executable, and requirejs error at last
  later = []

  # To invoke when multiple executable where added (added isnt null) and one of them was compiled.
  # Decrement added, and if added is zero, try to compile again all failing executable.
  # If the previous compilation try returns the same number of failing executable, do not try again,
  # and invoke the executable personnal error callback
  executableAdded = ->
    added--
    return unless added is 0

    # no more to add
    added = null
    return if later.length is 0

    # we retried to compile executables, but the same number is failing
    if lastAdded is later.length
      for args in later
        err = args[4]
        executable = args[0]
        # invoke callbacks with errors
        unless args[2]
          console.log executable.content
          console.error err
        executable.error = err
        args[1] err, null
      return later = []

    # store number of failing executable
    added = later.length
    lastAdded = later.length
    retry = later.concat()
    later = []
    # now retry to add failing executable
    compile args[0], args[1], args[2] for args in retry

  # Compiles and requires the executable content.
  # First, NodeJS requires are transformed into their RequireJS equivalent,
  # then the CoffeeScript code is compiled,
  # and at last the code is executed and required.
  #
  # @param executable [Executable] the compiled executable
  # @param callback [Function] invoked when the executable's content is available.
  # @option callback err [String] error message, or null if no error occured
  # @option callback exported [Object] the executable's content exported object.
  # @param silent [Boolean] disable the error log when something goes wrong. true by default.
  compile = (executable, callback, silent=true) ->
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

      # replace module.exports by return
      content = content.replace 'module.exports =', 'return'
      # indent all lines
      content = content.split('\n').join '\n  '
      
      # adds the define part
      extraStr = ""
      for extra, i in extras when extra?
        extraStr = "  #{vars[i].replace(/^__/, '').replace /__$/, ''} = #{vars[i]}#{extra}\n"

      content = "define '#{executable.id}', [#{deps.join ','}], (#{vars.join ','}) ->\n#{extraStr}\n  #{content}"

      # compiles and evaluates the resulting code
      eval coffee.compile content

      onError = (err) =>
        delete requirejs.onError
        if added?
          # rule probably depends on another loading executable. retry later
          later.push [executable, callback, silent, err]
          # do not trigger error behaviour
          return executableAdded()

        unless silent
          console.log content
          console.error err
        executable.error = err
        callback err, null
      requirejs.onError = onError

      # require the exported content
      require [executable.id], (exported) => 
        # rule properly compiled
        delete executable.error
        executableAdded() if added?
        callback null, exported
      , onError

    catch exc
      unless silent
        console.log content
        console.error exc
      callback exc, null

  # Client cache of executables.
  class _Executables extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Executable'

    # **private**
    # Return handler of `list` server method. 
    # Store number of added executable to properly handle interdependencies
    #
    # @param reqId [String] client request id
    # @param err [String] error message. Null if no error occured
    # @param modelName [String] reminds the listed class name.
    # @param models [Array<Object>] raw models.
    _onGetList: (reqId, err, modelName, models) =>
      unless modelName isnt @_className or err?
        added = models.length 
        lastAdded = null
      super reqId, err, modelName, models

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections Items instead
  #
  class Executable extends Base.Model

    # Local cache for models.
    @collection: new _Executables @

    # Executable kind: Rule, TurnRule or null.
    # First guessed on the executable content, then enforced after compilation
    kind: null

    # the exported object present inside the executable's content.
    exported: null

    # last compilation error
    error: null

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Executable'

    # **private**
    # List of model attributes that are localized.
    _i18nAttributes: []

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['content', 'path', 'category', 'rank', 'active']

    # **private**
    # the old value of exported rule's category.
    _oldCategory: null

    # **private**
    # the old value of exported turn rule's rank.
    _oldRank: null

    # **private**
    # the old value of exported turn rule's active status.
    _oldActive: null

    # Overload inherited setter to recompile when content changed.
    set: (key, value, options) =>
      # invoked superclass
      super key, value, options

      if key is 'content' or typeof key is 'object' and 'content' of key
        @kind = 'Rule' if -1 isnt @content?.indexOf 'extends Rule'
        @kind = 'TurnRule' if -1 isnt @content?.indexOf 'extends TurnRule'
        @error = null
        # recompiles content and store exported
        compile @, (err, exported) => 
          if err?
            # reset internal state as if rule was new
            @exported = null
            @error = err
            console.error "failed to compile #{@id}: #{err}"
            return @trigger 'change:error', @
          @exported = exported
          oldKind = @kind

          if exported instanceof Rule
            # rule specificity: category management
            @kind = 'Rule'
            if @exported?.category isnt @_oldCategory
              @_oldCategory = @exported?.category
              @trigger 'change:category', @

          else if exported instanceof TurnRule
            # turn rule specificity: rank management
            @kind = 'TurnRule'
            if @exported?.rank isnt @_oldRank
              @_oldRank = @exported?.rank
              @trigger 'change:rank', @

          if @exported?.active isnt @_oldActive
            @_oldActive = @exported?.active
            @trigger 'change:active', @

          # we missed the kind when constructing the model. Indicates to other parts
          app.router.trigger 'kindChanged', @ if oldKind isnt @kind

    # Overload inherited getter to add "virtual" attribute `category`, `rank` and `active`
    get: (key) =>
      # invoked superclass
      switch key
        when 'category' then @exported?.category
        when 'rank' then @exported?.rank or 0
        when 'active' then @exported?.active or true
        else super key