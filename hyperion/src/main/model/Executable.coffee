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

fs = require 'fs'
path = require 'path'
async = require 'async'
coffee = require 'coffee-script'
modelWatcher = require('./ModelWatcher').get()
logger = require('../logger').getLogger 'model'
utils = require '../utils'

root = utils.confKey 'executable.source'
compiledRoot = utils.confKey 'executable.target'
encoding = utils.confKey 'executable.encoding', 'utf8'
ext = utils.confKey 'executable.extension','.coffee'

utils.enforceFolderSync root, false, logger


# hashmap to differentiate creations from updates
wasNew= {}

# Do a single compilation of a source file.
#
# @param executable [Executable] the executable to compile
# @param silent [Boolean] disable change propagation if true
# @param callback [Function] end callback, invoked when the compilation is done with the following parameters
# @option callback err [String] an error message. Null if no error occured
# @option callback executable [Executable] the compiled executable
compileFile = (executable, silent, callback) ->
  try 
    js = coffee.compile executable.content, {bare: true}
  catch exc
    return callback "Error while compilling executable #{executable._id}: #{exc}"
  # Eventually, write a copy with a js extension
  fs.writeFile executable.compiledPath, js, (err) =>
    return callback "Error while saving compiled executable #{executable._id}: #{err}" if err?
    logger.debug "executable #{executable._id} successfully compiled"
    # store it in local cache.
    executables[executable._id] = executable
    # clean require cache.
    requireId = path.normalize path.join process.cwd(), executable.compiledPath
    delete require.cache[requireId]
    # propagate change
    unless silent
      modelWatcher.change (if wasNew[executable._id] then 'creation' else 'update'), "Executable", executable, ['content']
      delete wasNew[executable._id]
    # and invoke final callback
    callback null, executable

# Search inside existing executables. The following searches are supported:
# - {id,_id,name: String,RegExp]}: search by ids
# - {content: String,RegExp}: search inside executable content
# - {rank: Number}: search inside executable's exported rank attribute
# - {category: String,RegExp}: search inside executable's exported category attribute
# - {and: []}: logical AND between terms inside array
# - {or: []}: logical OR between terms inside array
# Error can be thrown if query isn't valid
#
# @param query [Object] the query object, which structure is validated
# @param all [Array] array of all executable to search within
# @param _operator [String] **inner usage only** operator used for recursion.
# @return a list (that may be empty) of matching executables
search = (query, all, _operator = null) ->
  if Array.isArray query
    return "arrays must contains at least two terms" if query.length < 2

    # we found an array inside a boolean term
    results = []
    for term, i in query
      # search each term
      tmp = search term, all
      if _operator is 'and' and i isnt 0
        # logical AND: retain only global results that match current results
        results = results.filter (result) -> -1 isnt tmp.indexOf result
      else 
        # logical OR: concat to global results, and avoid duplicates
        results = results.concat tmp.filter (result) -> -1 is results.indexOf result
    return results

  if 'object' is utils.type query
    # we found a term:  `{or: []}`, `{and: []}`, `{toto:1}`, `{toto:''}`, `{toto://}`
    keys = Object.keys query
    throw new Error "only one attribute is allowed inside query terms" if keys.length isnt 1
    
    field = keys[0] 
    value = query[field]
    if field is 'and' or field is 'or'
      # this is a boolean term: search inside
      return search value, all, field
    else
      field = '_id' if field is 'id' or field is 'name'
      if field is 'category' or field is 'rank'
        # TODO
        throw new Error 'not implemented yet'
      # this is a terminal term, validates value's type
      switch utils.type value
        when 'string', 'number', 'boolean'
          # performs exact match
          return all.filter (executable) -> executable[field] is value
        when 'regexp'
          # performs regexp match
          return all.filter (executable) -> value.test executable[field]
        else throw new Error "#{field}:#{value} is not a valid value"
  else
    throw new Error "'#{query}' is nor an array, nor an object"

# local cache of executables
executables = {}

# Executable are Javascript executable script, defined at runtime and serialized on the file-system
class Executable

  # Reset the executable local cache. It recompiles all existing executables
  #
  # @param callback [Function] invoked when the reset is done.
  # @option callback err [String] an error callback. Null if no error occured.
  @resetAll: (callback) ->
    # clean local files, and compiled scripts
    executables = {}
    utils.enforceFolderSync compiledRoot, true, logger

    fs.readdir root, (err, files) ->
      return callback "Error while listing executables: #{err}" if err?

      readFile = (file, end) -> 
        # only take coffeescript in account
        if ext isnt path.extname file
          return end()
        # creates an empty executable
        executable = new Executable {_id:file.replace ext, ''}

        fs.readFile executable.path, encoding, (err, content) ->
          return callback "Error while reading executable '#{executable._id}': #{err}" if err?
          # complete the executable content, and add it to the array.
          executable.content = content
          compileFile executable, true, (err, executable) ->
            return callback "Compilation failed: #{err}" if err?
            end()

      # each individual file must be read
      async.forEach files, readFile, (err) -> 
        logger.debug 'Local executables cached successfully reseted' unless err?
        callback err

  # Find existing executables.
  #
  # @param query [Object] optionnal condition to select relevant executables. Same syntax as MongoDB queries, supports:
  # - $and
  # - $or
  # - '_id'|'id'|'name' field (search by id) with string
  # - 'content' field (search in content) with string or regexp
  # - 'category' field (search rules' category) with string or regexp
  # - 'rank' field (search turn rules' rank) with number
  # @param callback [Function] invoked when all executables were retrieved
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback executables [Array<Executable>] list (may be empty) of executables
  @find: (query, callback) ->
    if 'function' is utils.type query
      callback = query
      query = null

    results = []
    # just take the local cache and transforms it into an array.
    results.push executable for _id, executable of executables
    # and perform search if relevant
    results = search query, results if query?
    callback null, results

  # Find existing executable by id, from the cache.
  #
  # @param id [String] the executable id
  # @param callback [Function] invoked when all executables were retrieved
  # @option callback err [String] an error message if an error occured. null otherwise
  # @option callback executable [Executable] the corresponding executable, of null if id doesn't match any executable
  @findCached: (id, callback) ->
    callback null, if id of executables then executables[id] else null

  # The unic file name of the executable, which is also its id.
  _id: null

  # The executable content (Utf-8 string encoded).
  content: ''

  # Absolute path to the executable source.
  path: ''

  # Absolute aath to the executable compiled script
  compiledPath: ''

  # Create a new executable, with its file name.
  # 
  # @param attributes object raw attributes, containing: 
  # @option attributes_id [String] its file name (without it's path).
  # @option attributes content [String] the file content. Empty by default.
  constructor: (attributes) ->
    @_id = attributes._id
    @content = attributes.content || ''
    @path = path.join root, @_id+ext
    @compiledPath = path.join compiledRoot, @_id+'.js'

  # Save (or update) a executable and its content.
  # 
  # @param callback [Function] called when the save is finished, with two arguments:
  #   @param err [String] error string. Null if save succeeded
  #   @param item [Item] the saved item
  save: (callback) =>
    wasNew[@_id] = !(@_id of executables)
    fs.writeFile @path, @content, encoding, (err) =>
      return callback "Error while saving executable #{@_id}: #{err}" if err?
      logger.debug "executable #{@_id} successfully saved"
      # Trigger the compilation.
      compileFile @, false, callback

  # Remove an existing executable.
  # 
  # @param callback [Function] called when the save is finished, with two arguments:
  #   @param err [String] error string. Null if save succeeded
  #   @param item [Item] the saved item
  remove: (callback) =>
    fs.exists @path, (exists) =>
      return callback "Error while removing executable #{@_id}: this executable does not exists" if not exists
      delete executables[@_id]
      fs.unlink @path, (err) =>
        return callback "Error while removing executable #{@_id}: #{err}" if err?
        fs.unlink @compiledPath, (err) =>
          logger.debug "executable #{@_id} successfully removed"
          # propagate change
          modelWatcher.change 'deletion', "Executable", @
          callback null, @

  # Provide the equals() method to check correctly the equality between _ids.
  #
  # @param other [Object] other object against which the current object is compared
  # @return true if both objects have the same _id, false otherwise
  equals: (object) =>
    @_id is object?._id

module.exports = Executable
