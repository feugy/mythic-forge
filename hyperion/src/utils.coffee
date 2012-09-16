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

_ = require 'underscore'
yaml = require 'js-yaml'
fs = require 'fs-extra'
async = require 'async'
pathUtil = require 'path'

classToType = {}
for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
  classToType["[object " + name + "]"] = name.toLowerCase()

conf = null
  
# This method is intended to replace the broken typeof() Javascript operator.
#
# @param obj [Object] any check object
# @return the string representation of the object type. One of the following:
# object, boolean, number, string, function, array, date, regexp, undefined, null
#
# @see http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
type = (obj) ->
  strType = Object::toString.call(obj)
  classToType[strType] or "object"

# Recursively find files that match a given pattern, in name, content or both.
#
# @param path [String] the path under wich files are searched
# @param regex [RegExp] regexp on which file names are tested
# @param contentRegEx [RegExp] regexp on which file content are tested. Optionnal
# @param callback [Function] search end function:
# @option callback err [String] an error string, or null if no error occured
# @option callback results [Array] matching file names (may be empty)
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

  find: find

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
      return true  if currentClass.name == clazz.name
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
        fs.mkdirSync folderPath
        logger?.info "Folder '#{folderPath}' successfully created"
      catch err
        throw "Unable to create the Executable folder '#{folderPath}': #{err}"

  # Allows to add i18n fields on a Mongoose schema.
  # adds a transient attribute `locale` that allows to manage model locale.
  #
  # @param schema [Schema] the concerned Mongoose schema
  enhanceI18n: (schema) ->
    schema.virtual('locale')
      .get () ->
        if @_locale? then @_locale else 'default'
      .set (value) ->
        @_locale = value

  # Creates an internatializable field inside a Mongoose Schema.
  # A "private" field prefixed with `_` holds all translation.
  # A virtual field with getter and setter allow to access translations.
  # To change the translation of a field, change the `locale` attribute of the model.
  #
  # You must first use `enhanceI18n()` on the schema.
  #
  # @param schema [Schema] the concerned Mongoose schema
  # @param field [String] name of the i18n field.
  # @param options [Object] optionnal options used to create the real field. Allow to specify validation of required status.
  addI18n: (schema, field, options = {}) ->
    throw new Error 'please call enhanceI18n on schema before adding it i18n fields' if 'locale' of schema
    spec = {}
    spec["_#{field}"] = _.extend options, {type: {}, default: -> {}}
    schema.add spec
    schema.virtual(field)
      .get () ->
        # check the local existence.
        locale = @get 'locale'
        throw new Error "unknown locale #{locale} for field #{field} of model #{@_id}" unless locale of @get("_#{field}")
        @get("_#{field}")[locale]
      .set (value) ->
        @get("_#{field}")[@get 'locale'] = value
        @markModified "_#{field}"

  # Enforce that a property value does not violate its corresponding definition.
  #
  # @param value [Object] the checked value.
  # @param property [Object] the property definition
  # @option property type [String] the awaited type. Could be: string, text, boolean, integer, float, date, array or object
  # @option property def [Object] the default value. For array and objects, indicate the class of the awaited linked objects.
  checkPropertyType: (value,  property) ->
    err = null

    # string and text: null or typeof is string
    checkString = ->
      err = "#{value} isn't a valid string" unless value is null or 
        typeof value is 'string'

    # object: null or object with a __proto__ that have the good name.    
    checkObject = (val, isArray) ->
      err = "#{value} isn't a valid #{property.def}" if val isnt null and 
        (typeof val isnt 'object' or val?.collection?.name isnt property.def.toLowerCase()+'s')

    switch property.type 
      # integer: null or float = int value of a number/object
      when 'integer' then err = "#{value} isn't a valid integer" unless value is null or 
        ((typeof value is 'number' or typeof value is 'object') and 
        parseFloat(value, 10) is parseInt(value, 10))
      # foat: null or float value of a number/object
      when 'float' then err = "#{value} isn't a valid float" unless value is null or 
        ((typeof value is 'number' or typeof value is 'object') and not 
        isNaN parseFloat(value, 10))
      # boolean: null or value is false or true and not a string
      when 'boolean' 
        strVal = "#{value}".toLowerCase()
        err = "#{value} isn't a valid boolean" if value isnt null and
          (typeof value is 'string' or 
          (strVal isnt 'true' and strVal isnt 'false'))
      # date : null or typeof is date
      when 'date' then err = "#{value} isn't a valid date" unless value is null or 
        value instanceof Date
      when 'object' then checkObject(value, false)
      # array: array that contains object at each index.
      when 'array'
        if value instanceof Array 
          checkObject obj for obj in value
        else 
          err = "#{value} isn't a valid array of #{property.def}"
      when 'string' then checkString()
      when 'text' then checkString()
      else err = "#{property.type} isn't a valid type"
    err

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

  # Collapse history, from a given version to previous tag (or begining)
  # Will create a tag to aim at the new collasped commit.
  # The first original commit cannot never be collapsed.
  #
  # @param repo [Git] Git tools configured on the right repository
  # @param tag [String] the tag name that will be used to create the collapse
  # @param callback [Function] collapsing end function, invoked with
  # @option callback err [String] an error details string, or null if no error occured.
  collapseHistory: (repo, to, callback) ->
    # get commit id corresponding to tag
    repo.tags (err, tags) ->
      return callback "failed to check tags: #{err}" if err?
      names = _.pluck tags, 'name'

      # checks tags validity
      return callback "cannot reuse existing tag #{to}" if to in names

      finish = ->
        # then reset to it, leaving the working copy unmodified
        repo.git 'reset', mixed:true, from, (err, stdout, stderr) ->
          return callback "failed to go back to revision #{from}: #{err}" if err?

          # now we can add and remove everything in only one commit
          repo.add [], all:true, (err, stdout, stderr) ->
            return callback "failed to add the working copy: #{err}" if err?
            repo.commit "collapse for #{to}", all:true, (err, stdout, stderr) ->
              # ignore warnings about empty working copy
              err = null if err? and -1 isnt stdout?.indexOf 'nothing to commit'
              return callback "failed to commit the working copy: #{err}" if err?

              # and at last ceates the tag
              repo.create_tag to, (err) ->
                return callback "failed to create tag: #{err}" if eff?
                callback null

      if tags.length > 0
        # get commit is corresponding to last tag
        from = tags.pop().commit.id
        finish()
      else
        # get first commit
        repo.commits (err, history) ->
          return callback "failed to check history: #{err}" if err?
          from = history.pop().id
          finish()