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
  'model/sockets'
  'coffeescript'
  'utils/utilities'
  'model/TurnRule'
  'model/Rule'
], (Base, sockets, coffee, utils, TurnRule, Rule) ->

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
    require.undef(executable.id)

    try 
      # then, modifies NodeJS's require into RequireJS dependencies
      content = executable.get('content')

      # Regular expression to extract dependencies from rules
      depReg = /(\S*)\s*=\s*require[\(\s](\S*)\)?\s*\n/

      # gets the required dependencies
      deps = []
      vars = []
      while -1 isnt content.search(depReg)
        # removes the require directive and extract relevant variable and path
        content = content.replace(depReg, (str, variable, dep)->
          deps.push(dep.replace(/^'\.\.\/main\//, "'"))
          vars.push(variable)
          return ''
        )

      # replace module.exports by return
      content = content.replace('module.exports =', 'return')
      # indent all lines
      content = content.split('\n').join('\n  ')
      
      # adds the define part
      content = "define '#{executable.id}', [#{deps.join ','}], (#{vars.join ','}) ->\n  #{content}"

      # compiles and evaluates the resulting code
      eval(coffee.compile(content))

      requirejs.onError = (err) =>
        console.error(err) unless silent
        delete(requirejs.onError)
        callback(err, null)

      # require the exported content
      require([executable.id], (exported) => 
        callback(null, exported)
      )

    catch exc
      unless silent
        console.log(content)
        console.error(exc) 
      callback(exc, null)

  # Client cache of executables.
  class Executables extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Executable'

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections Items instead
  #
  class Executable extends Base.Model

    # Local cache for models.
    @collection = new Executables(@)

    # Executable kind: rule, turnRule or null.
    # First guessed on the executable content, then enforced after compilation
    kind: null

    # the exported object present inside the executable's content.
    exported: null

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Executable'

    # **private**
    # List of model attributes that are localized.
    _i18nAttributes: []

    # **private**
    # the old value of exported rule's category.
    _oldCategory: null

    # **private**
    # the old value of exported turn rule's rank.
    _oldRank: null

    # **private**
    # the old value of exported turn rule's active status.
    _oldActive: null

    # Provide a custom sync method to wire Types to the server.
    # Customize the update behaviour to rename if necessary.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments. For executable renaming, please specify `newId` string value while updating.
    sync: (method, collection, args) =>
      switch method 
        when 'update' 
          # for update, we do not use 'save' method, but the 'saveAndRename' one.
          sockets.admin.once('saveAndRename-resp', (err) =>
            rheia.router.trigger('serverError', err, {method:'Executable.sync', details:method, id:@id}) if err?
          )
          sockets.admin.emit('saveAndRename', @toJSON(), args.newId)
        else super(method, collection, args)

    # Overload inherited setter to recompile when content changed.
    set: (key, value, options) =>
      # invoked superclass
      super(key, value, options)

      if key is 'content' or typeof key is 'object' and 'content' of key
        @kind = 'rule' if @get('content')?.indexOf('extends Rule') isnt -1
        @kind = 'turnRule' if @get('content')?.indexOf('extends TurnRule') isnt -1
        # recompiles content and store exported
        compile(@, (err, exported) => 
          @exported = exported
          if exported instanceof Rule
            # rule specificity: category management
            @kind = 'rule'
            if @exported?.category isnt @_oldCategory
              @_oldCategory = @exported?.category
              @trigger('change:category', @)

          else if exported instanceof TurnRule
            # turn rule specificity: rank management
            @kind = 'turnRule'
            if @exported?.rank isnt @_oldRank
              @_oldRank = @exported?.rank
              @trigger('change:rank', @)

          if @exported?.active isnt @_oldActive
            @_oldActive = @exported?.active
            @trigger('change:active', @)
        )

    # Overload inherited getter to add "virtual" attribute `category`, `rank` and `active`
    get: (key) =>
      # invoked superclass
      switch key
        when 'category' then @exported?.category
        when 'rank' then @exported?.rank
        when 'active' then @exported?.active
        else super(key)

  return Executable