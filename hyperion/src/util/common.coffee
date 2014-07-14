###
  Copyright 2010~2014 Damien Feugas
  
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

yaml = require 'js-yaml'
fs = require 'fs-extra'
{resolve, normalize, join, sep} = require 'path'
stacktrace = require 'stack-trace'
async = require 'async'
_ = require 'underscore'
EventEmitter = require('events').EventEmitter


# use an event emitter to propagate configuration changes
emitter = new EventEmitter()
emitter.setMaxListeners 0

# value search to forbid usage from executables target
forbidRoot = null

# Read a configuration key inside the YAML configuration file (utf-8 encoded).
# At first call, performs a synchronous disk access, because configuraiton is very likely to be read
# before any other operation. The configuration is then cached.
# 
# The configuration file read is named 'xxx-conf.yaml', where xxx is the value of NODE_ENV (dev if not defined) 
# and located in a "conf" folder under the execution root.
#
# @param key [String] the path to the requested key, splited with dots.
# @param def [Object] the default value, used if key not present. 
# If undefined, and if the key is missing, an error is thrown.
# @return the expected key.
emitter.confKey = (key, def) -> 
  path = key.split '.'
  obj = conf
  last = path.length-1
  for step, i in path
    unless step of obj
      # missing key or step
      throw new Error "The #{key} key is not defined in the configuration file #{confPath}" if def is undefined
      return def
    unless i is last
      # goes deeper
      obj = obj[step]
    else 
      # last step: returns value
      return obj[step]

# read configuration file
conf = null
confPath = resolve "#{process.cwd()}/conf/#{if process.env.NODE_ENV then process.env.NODE_ENV else 'dev'}-conf.yml"
parseConf = ->
  try 
    conf = yaml.load fs.readFileSync confPath, 'utf8'
  catch err
    throw new Error "Cannot read or parse configuration file '#{confPath}': #{err}"
  # init required rule
  forbidRoot = resolve(normalize emitter.confKey 'game.executable.target').replace /\//g, '\\'

parseConf()

# read again if file is changed
fs.watch confPath, ->
  _.defer ->
    parseConf()
    emitter.emit 'confChanged'

# This method is intended to replace the broken typeof() Javascript operator.
#
# @param obj [Object] any check object
# @return the string representation of the object type. One of the following:
# object, boolean, number, string, function, array, date, regexp, undefined, null
#
# @see http://bonsaiden.github.com/JavaScript-Garden/#types.typeof
emitter.type = (obj) -> Object::toString.call(obj).slice(8, -1)?.toLowerCase() or 'undefined'

# isA() is an utility method that check if an object belongs to a certain class, or to one 
# of it's subclasses. Uses the classes names to performs the test.
#
# @param obj [Object] the object which is tested
# @param clazz [Class] the class against which the object is tested
# @return true if this object is a the specified class, or one of its subclasses. false otherwise
emitter.isA = (obj, clazz) ->
  return false if not (obj? and clazz?)
  currentClass = obj.constructor
  while currentClass?
    return true if currentClass.name.toLowerCase() is clazz.name.toLowerCase()
    currentClass = currentClass.__super__?.constructor
  false

# Enforce the folder existence.
# This function IS intended to be synchonous, to enforce folder existence before executing code.
# Allows to remove existing folder if necessary.
#
# @param folderPath [String] path to the checked folder
# @param forceRemove [boolean] if specifed and true, first erase the folder.
# @param logger [Object] optional logger
emitter.enforceFolderSync = (folderPath, forceRemove = false, logger = null) ->
  return if emitter.fromRule()
  exists = fs.existsSync folderPath

  # force Removal if specified
  if forceRemove and exists
    fs.removeSync folderPath 
    exists = false
  
  # creates if needed  
  unless exists
    try 
      fs.mkdirsSync folderPath
      logger?.info "Folder '#{folderPath}' successfully created"
    catch err
      console.trace()
      throw "Unable to create the folder '#{folderPath}': #{err}"

# Enforce the folder existence.
# Allows to remove existing folder if necessary.
#
# @param folderPath [String] path to the checked folder
# @param forceRemove [boolean] if specifed and true, first erase the folder.
# @param logger [Object] logger (may be null)
# @param callback [Function] end callback invoked with an error string as first argument if something
# goes wrong, and null if the folder was properly created
emitter.enforceFolder = (folderPath, forceRemove, logger, callback) ->
  return if emitter.fromRule callback
  fs.exists folderPath, (exists) ->
    create = (err) ->
      return callback "Failed to remove #{folderPath}: #{err}" if err?
      # creates only if needed  
      return callback null if exists
    
      fs.mkdirs folderPath, (err) ->
        return callback "Failed to create #{folderPath}: #{err}" if err
        logger?.info "Folder '#{folderPath}' successfully created"
        callback null

    # force Removal if specified
    if forceRemove and exists
      exists = false
      return fs.remove folderPath, create 

    create()

# Recursively find files that match a given pattern, in name, content or both.
#
# @param path [String] the path under wich files are searched
# @param regex [RegExp] regexp on which file names are tested
# @param contentRegEx [RegExp] regexp on which file content are tested. Optionnal
# @param callback [Function] search end function:
# @option callback err [String] an error string, or null if no error occured
# @option callback results [Array] matching file names (may be empty)   
emitter.find = (path, regex, contentRegEx, callback) ->
  return if emitter.fromRule callback
  if 'function' is emitter.type contentRegEx
    callback = contentRegEx
    contentRegEx = null

  # check file nature
  fs.stat path, (err, stats) ->
    return callback err if err?

    # only returns matching files
    if stats.isFile()
      # checks file name
      return callback null, [] unless regex.test path
      # then content if needed
      return callback null, [path] unless contentRegEx?
      fs.readFile path, (err, content) ->
        return callback err if err?
        callback null, (if contentRegEx.test content then [path] else []) 

    else
      # or recurisvely search in folders
      fs.readdir path, (err, children) ->
        return callback err if err?
        results = []
        async.forEach children, (child, next) ->
          # check child nature
          emitter.find join(path, child), regex, contentRegEx, (err, subResults) ->
            return next err if err?
            results = results.concat subResults
            next()
        , (err) ->
          return callback err if err?
          callback null, results

# Simple utility that generate a random token containing alphanumerical characters
# 
# @param length [Number] the generated token length
# @return a random token
emitter.generateToken = (length) ->
  token = ''
  while token.length < length
    # random betwenn 48 (0) and 90 (Z)
    rand = 48+Math.floor Math.random()*43
    continue if rand >= 58 and rand <= 64 # ignore : ; < = > ? @
    token += String.fromCharCode(rand).toLowerCase()
  token

# files/folders common behaviour: handle different error codes and retry if possible
#
# @param path [String] removed folder or file
# @param err [Object] underlying error, or null if removal succeeded
# @param callback [Function] processing end callback, invoked with arguments
# @option callback err [Object] an error object, or null if removal succeeded
_processOp = (path, err, callback) ->
  unless err?
    return callback null 
  switch err.code 
    when 'EPERM'
      # removal not allowed: try to change permissions
      fs.chmod path, '755', (err) ->
        return callback new Error "failed to change #{path} permission before removal: #{err}" if err?
        emitter.remove path, callback
    when 'ENOTEMPTY', 'EBUSY'
      # not empty folder: just let some time to OS to really perform deletion
      _.defer ->
        emitter.remove path, callback
      , 50
    when 'ENOENT'
      # no file/folder: it's a success :)
      callback null
    else
      callback new Error "failed to remove #{path}: #{err}"

# files/folders common behaviour: handle different error codes and retry if possible
#
# @param path [String] removed folder or file
# @param err [Object] underlying error, or null if removal succeeded
_processOpSync = (path, err) ->
  return unless err?
  switch err.code 
    when 'EPERM'
      # removal not allowed: try to change permissions
      try
        fs.chmodSync path, '755'
        emitter.removeSync path
      catch err
        throw new Error "failed to change #{path} permission before removal: #{err}"
    when 'ENOTEMPTY', 'EBUSY'
      # not empty folder: just retry
      emitter.removeSync path
    when 'ENOENT'
      return
    else
      throw new Error "failed to remove #{path}: #{err}"

# rimraf's remove (used in fs-extra) have many problems on windows: provide a custom naive implementation.
#
# @param path removed file of folder
# @param callback [Function] end callback, executed with one parameter:
# @option callback err [String] error message. Null if no error occured.
emitter.remove = (path, callback) ->
  callback ||= -> 
  return if emitter.fromRule callback
  fs.stat path, (err, stats) ->
    _processOp path, err, (err) ->
      return callback() unless stats?
      return callback err if err?
      # a file: unlink it
      if stats.isFile()
        return fs.unlink path, (err) -> _processOp path, err, callback
      # a folder, recurse with async
      fs.readdir path, (err, contents) ->
        return callback new Error "failed to remove #{path}: #{err}" if err?
        async.forEach (join path, content for content in contents), emitter.remove, (err) ->
          return callback err if err?
          # remove folder once empty
          fs.rmdir path, (err) -> _processOp path, err, callback

# rimraf's removeSync (used in fs-extra) have many problems on windows: provide a custom naive implementation.
#
# @param path removed file of folder
# @throws err if the removal failed
emitter.removeSync = (path) ->
  return if emitter.fromRule()
  try 
    stats = fs.statSync path
    # a file: unlink it
    if stats.isFile()
      try
        fs.unlinkSync path
      catch err
        _processOpSync path, err
    else
      # a folder, recurse with async
      contents = (join path, content for content in fs.readdirSync path)
      emitter.removeSync content for content in contents
      # remove folder once empty
      try 
        fs.rmdirSync path
      catch err
        _processOpSync path, err
  catch err
    _processOpSync path, err

# Remove everything inside the specified folder, but does not removes the folder itself.
# Recurse inside sub-folders, using remove() method.
#
# @param path [String] full path to rhe concerned folder
# @param callback [Function] end callback, executed with one parameter:
# @option callback err [String] error message. Null if no error occured.
emitter.empty = (path, callback) ->
  return if emitter.fromRule callback
  fs.readdir path, (err, files) ->
    return callback err if err?
    
    async.forEachSeries files, (file, next) ->
      emitter.remove join(path, file), next
    , (err) ->
      return callback err if err?
      # use a slight delay to let underlying os really remove content
      _.defer -> 
        callback null
      , 50

# Compute the relative path of a folder B from another one A
#
# @param aPath [String] absolute path of reference folder
# @param bPath [String] absolute path of target folder
# @eturn the relative path from A to reach B
emitter.relativePath = (aPath, bPath) ->
  aPath = normalize aPath
  aPathSteps = aPath.split sep
  aLength = aPathSteps.length
  bPath = normalize bPath
  bPathSteps = bPath.split sep
  bLength = bPathSteps.length
  
  suffix = ''
  stepBack = 0

  if 0 is aPath.indexOf bPath
    # easy: a contains b. Just go a few steps back
    stepBack = aLength-bLength
  else
    for i in [0..bLength-1]
      # find the step where a and b differs
      if aPathSteps[i] is bPathSteps[i]
        # if reached a end, just add b remaining steps
        continue unless i is aLength-1
        suffix = ".#{sep}#{bPathSteps[i+1..bLength].join sep}"
      else
        # now go back of a remaining steps, and go forth of b remaining steps
        stepBack = aLength-i
        suffix = "#{sep}#{bPathSteps[i..bLength].join sep}" if i < bLength
      break

  path = ''
  for i in [0...stepBack]
    path += '..'
    path += sep unless i is stepBack-1
  "#{path}#{suffix}" 

# Simple method to remove occurence of the root path from error messages
#
# @param err [Error|String] purged error or string
# @param root [String] root folder path removed from string.
# @return the pureged string.
emitter.purgeFolder = (err, root) -> 
  return if emitter.fromRule()
  err = err.message if emitter.isA err, Error
  err.replace new RegExp("#{root.replace /\\/g, '\\\\'}", 'g'), '' if 'string'


# Transforms models into plain JSON, using their toJSON() method
# Goes deeper into arrays and objects to find models
# Do NOT send circular trees !
#
# @param args [Object|Array] models to transform to plain JSON
# @return the corresponding plain JSON
emitter.plainObjects = (args) ->
  isArray = 'array' is emitter.type args
  unless isArray
    args = [args] 
  for arg, i in args 
    if 'array' is emitter.type arg
      args[i] = emitter.plainObjects arg
    if 'object' is emitter.type(arg) 
      if 'function' is emitter.type arg.toJSON
        args[i] = arg.toJSON()
      else
        arg[attr] = emitter.plainObjects([val])[0] for attr, val of arg
  if isArray then args else args[0]
  
serviceRoot = join 'hyperion', 'lib', 'service'
console.log serviceRoot

# Prevent using critical functionnalities from rules, scripts and turn rules.
# Intended to be used synchronously in a test:
#
# criticalTreatment: (arg1, callback) ->
#   return if fromRule callback
#   ...
#
# @param callback [Function] optionnal callback invoked if caller is an executable
# @option callback error [Error] an error object
# @return a function to invoke true if caller is not allowed, false otherwise
emitter.fromRule = (callback = ->) ->
  # rank of the first line containing service
  foundService = false
  for line, i in stacktrace.get()
    line = line.getFileName()
    console.log line
    # we found a line coming from services that is not the fromRule() and bind invokation
    foundService = true unless i <= 2  or foundService or -1 is line.indexOf serviceRoot
    # invoked from compilation folder: forbidden
    if 0 is line.indexOf forbidRoot
      # invoked from a service: do not goes further cause its allowed
      return false if foundService
      callback new Error "this functionnality is denied to executables"
      return true
  false

module.exports = emitter