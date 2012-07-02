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
###
'use strict'

_ = require 'underscore'
yaml = require 'js-yaml'
rimraf = require 'rimraf'
fs = require 'fs'
pathUtil = require 'path'

classToType = {}
for name in "Boolean Number String Function Array Date RegExp Undefined Null".split(" ")
  classToType["[object " + name + "]"] = name.toLowerCase()

conf = null

module.exports =
  
  # This method is intended to replace the broken typeof() Javascript operator.
  #
  # @param obj [Object] any check object
  # @return the string representation of the object type. One of the following:
  # object, boolean, number, string, function, array, date, regexp, undefined, null
  #
  # @see http://arcturo.github.com/library/coffeescript/07_the_bad_parts.html
  type: (obj) ->
    strType = Object::toString.call(obj)
    classToType[strType] or "object"

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
      confPath = pathUtil.resolve "#{__dirname}/../../conf/#{if process.env.NODE_ENV then process.env.NODE_ENV else 'dev'}-conf.yml"
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
  enforceFolderSync: (folderPath, forceRemove) ->
    # force Removal if specified
    rimraf.sync folderPath if forceRemove and fs.existsSync folderPath
      
    if not fs.existsSync folderPath
      try 
        fs.mkdirSync folderPath
        console.info "Executable folder '#{folderPath}' successfully created"
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