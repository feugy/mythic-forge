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

yaml = require 'js-yaml'
fs = require 'fs-extra'
pathUtil = require 'path'
async = require 'async'

conf = null

type = (obj) -> Object::toString.call(obj).slice(8, -1)?.toLowerCase() or 'undefined'

find = (path, regex, contentRegEx, callback) ->
  if 'function' is type contentRegEx
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
          find pathUtil.join(path, child), regex, contentRegEx, (err, subResults) ->
            return next err if err?
            results = results.concat subResults
            next()
        , (err) ->
          return callback err if err?
          callback null, results

module.exports =

  # This method is intended to replace the broken typeof() Javascript operator.
  #
  # @param obj [Object] any check object
  # @return the string representation of the object type. One of the following:
  # object, boolean, number, string, function, array, date, regexp, undefined, null
  #
  # @see http://bonsaiden.github.com/JavaScript-Garden/#types.typeof
  type: type

  # isA() is an utility method that check if an object belongs to a certain class, or to one 
  # of it's subclasses. Uses the classes names to performs the test.
  #
  # @param obj [Object] the object which is tested
  # @param clazz [Class] the class against which the object is tested
  # @return true if this object is a the specified class, or one of its subclasses. false otherwise
  isA: (obj, clazz) ->
    return false if not (obj? and clazz?)
    currentClass = obj.constructor
    while currentClass?
      return true if currentClass.name is clazz.name
      currentClass = currentClass.__super__?.constructor
    false

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
  confKey: (key, def) ->
    if conf is null
      confPath = pathUtil.resolve "#{process.cwd()}/conf/#{if process.env.NODE_ENV then process.env.NODE_ENV else 'dev'}-conf.yml"
      try 
        conf = yaml.load fs.readFileSync confPath, 'utf8'
      catch err
        throw new Error "Cannot read or parse configuration file '#{confPath}': #{err}"
    
    path = key.split '.'
    obj =  conf
    last = path.length-1
    for step, i in path
      unless step of obj
        # missing key or step
        throw new Error "The #{key} key is not defined in the configuration file" if def is undefined
        return def
      unless i is last
        # goes deeper
        obj = obj[step]
      else 
        # last step: returns value
        return obj[step]

  # Enforce the folder existence.
  # This function IS intended to be synchonous, to enforce folder existence before executing code.
  # Allows to remove existing folder if necessary.
  #
  # @param folderPath [String] path to the checked folder
  # @param forceRemove [boolean] if specifed and true, first erase the folder.
  # @param logger [Object] optional logger
  enforceFolderSync: (folderPath, forceRemove = false, logger = null) ->
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
        console.trace();
        throw "Unable to create the folder '#{folderPath}': #{err}"

  # Recursively find files that match a given pattern, in name, content or both.
  #
  # @param path [String] the path under wich files are searched
  # @param regex [RegExp] regexp on which file names are tested
  # @param contentRegEx [RegExp] regexp on which file content are tested. Optionnal
  # @param callback [Function] search end function:
  # @option callback err [String] an error string, or null if no error occured
  # @option callback results [Array] matching file names (may be empty)
  find: find

  # Simple utility that generate a random token containing alphanumerical characters
  # 
  # @param length [Number] the generated token length
  # @return a random token
  generateToken: (length) ->
    token = ''
    while token.length < length
      # random betwenn 48 (0) and 90 (Z)
      rand = 48+Math.floor Math.random()*43
      continue if rand >= 58 and rand <= 64 # ignore : ; < = > ? @
      token += String.fromCharCode(rand).toLowerCase()
    token