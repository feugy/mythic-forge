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
async = require 'async'
ObjectId = require('mongodb').BSONPure.ObjectID
Model = require('mongoose').Model
watcher = require('../model/ModelWatcher').get()
utils = require '../util/common'

# cache eviction timeout, to avoid triggering multiple eviction loops
eviction = null

# string and text: null or type is string
checkString = (val, property) ->
  return null if val is null or 'string' is utils.type val
  "'#{val}' isn't a valid #{property.type}" 

# object: null or string (id) or object with a collection that have the good name.    
checkObject = (val, property) ->
  return null if val is null or 'string' is utils.type val
  return "#{val} isn't a valid #{property.def}" unless 'object' is utils.type val
  unless val?.collection?.name is "#{property.def.toLowerCase()}s" or property.def.toLowerCase() is 'any' and utils.isA val, Model
    "#{val} isn't a valid #{property.def}" 
  else
    null

# Json: null or plain json object (stringify/parse roundtrip)
checkJSON = (val, property) ->
  return null if val is null
  return "JSON #{property.type} only accepts arrays and object" unless utils.type(val) in ['array', 'object']
  try
    previous = []
    check = (val) ->
      throw 'circular reference are not valid JSON values' if val in previous
      switch utils.type val
        when 'array' 
          previous.push val
          check v for v,i in val
        when 'object' 
          previous.push val
          check v for k,v of val
        when 'function' then throw 'function are not valid JSON values' 
    check val
  catch err
    return "#{property.type} doesn't hold a valid JSON object"
  null

checkPropertyType = (value,  property) ->
  err = null
  switch property.type 
    # integer: null or float = int value of a number/object
    when 'integer' then err = "#{value} isn't a valid integer" unless value is null or 
      ('number' is utils.type(value) and parseFloat(value, 10) is parseInt(value, 10))
    # foat: null or float value of a number/object
    when 'float' then err = "#{value} isn't a valid float" unless value is null or 
      ('number' is utils.type(value) and not isNaN parseFloat(value, 10))
    # boolean: null or value is false or true and not a string nor array
    when 'boolean' 
      strVal = "#{value}".toLowerCase()
      err = "#{value} isn't a valid boolean" if value isnt null and
        ('array' is utils.type(value) or 'string' is utils.type(value) or (strVal isnt 'true' and strVal isnt 'false'))
    # date : null or type is date
    when 'date', 'time', 'datetime' 
      if value isnt null
        if 'string' is utils.type value 
          err = "#{value} isn't a valid date" if isNaN new Date(value).getTime()
        else if 'date' isnt utils.type(value) or isNaN value.getTime()
          err = "#{value} isn't a valid date" 
    when 'object' then err = checkObject value, property
    # array: array that contains object at each index.
    when 'array'
      if Array.isArray value
        err = checkObject obj, property for obj in value
      else 
        err = "#{value} isn't a valid array of #{property.def}"
    when 'string' then err = checkString value, property
    when 'text' then err = checkString value, property
    when 'json' then err = checkJSON value, property
    else err = "#{property.type} isn't a valid type"
  err

getProp = (obj, path, callback) ->
  return callback "invalid path '#{path}'" unless 'string' is utils.type path
  steps = path.split '.'
  
  processStep = (obj) ->
    step = steps.splice(0, 1)[0]
    
    # first check sub-array
    bracket = step.indexOf '['
    index = -1
    if bracket isnt -1
      # sub-array awaited
      bracketEnd = step.indexOf ']', bracket
      if bracketEnd > bracket
        index = parseInt step.substring bracket+1, bracketEnd
        step = step.substring 0, bracket
        
    # check the property existence
    return callback null, undefined unless 'object' is utils.type(obj) and step of obj
    
    # store obj inside the list of updatable objects
    subObj = if index isnt -1 then obj[step][index] else obj[step]
    
    endStep = ->
      # iterate on sub object or returns value
      if steps.length is 0
        return callback null, subObj
      else
        processStep subObj
        
    # if the object has a type and the path is along an object/array property
    if obj.type?.properties?[step]?.type is 'object' or obj.type?.properties?[step]?.type is 'array'
      # we may need to load object.
      if ('array' is utils.type(subObj) and 'string' is utils.type subObj?[0]) or 'string' is utils.type subObj
        obj.fetch (err, obj) ->
          return callback "error on loading step #{step} along path #{path}: #{err}" if err?
          subObj = if index isnt -1 then obj[step][index] else obj[step]
          endStep()
      else
        endStep()
    else
      endStep()
  
  processStep obj

module.exports =

  # Generate a random Id (using Mong native id)
  # @return a generated Id
  generateId: =>
    new ObjectId().toString()

  # Removes duplicate models from a given model array (directly modifies it)
  #
  # @param arr [Array<Model>] array of model that will be purged
  purgeDuplicates: (arr) =>
    uniq = []
    length = arr.length
    i = 0
    while i < length
      model = arr[i]
      if model.id? 
        # check on id equality
        duplicate = _.any(uniq, (obj) -> obj?.equals and obj.equals model)
      else
        # or on strict equality
        duplicate = -1 isnt uniq.indexOf model

      if duplicate
        # found a duplicate on id equality
        arr.splice i, 1
        length--
      else
        uniq.push model
        i++

  # Enforce that a property value does not violate its corresponding definition.
  #
  # @param value [Object] the checked value.
  # @param property [Object] the property definition
  # @option property type [String] the awaited type. Could be: string, text, boolean, integer, float, date, time, datetime, array, object or json
  # @option property def [Object] the default value. For array and objects, indicate the class of the awaited linked objects.
  # @return null if value is correct, an error string otherwise
  checkPropertyType: checkPropertyType

  # Within a rule execution, checks that passed parameters do not violate constraints of awaited parameters.
  # Expected parameters must at least contain:
  # - name: [String] the parameter name (a valid Javascript identifier)
  # - type: [String] the value expected type, that can be: string, text, boolean, integer, float, date, time, datetime, object, json
  #
  # Optionnal constraints may include:
  # - min: [Number/Date] minimum accepted value (included) for integer, float, date, time and datetime
  # - max: [Number/Date] maximum accepted value (included) for integer, float, date, time and datetime
  # - within: [Array<String>] list of acceptable values for string, acceptable ids for objects.
  # - property: [Object] path to a given property, specified by 'path' attribute (a string) and from 
  # (a string that may be 'actor' or 'target'), for object
  # - match: [String] string representation of a regular expression that will contraint string
  # - numMin: [Number] indicate the minium number of awaited value occurence. For all types, default to 1
  # - numMax: [Number] indicate the maximum number of awaited value occurence. For all types, default to 1
  #
  # The 'object' parameters have particular behaviour. 
  # Their values are always constrained within a list of choices ('within' constraint, or content of the 
  # property aimed by 'path' constraint) 
  # The awaited values are object ids for events and unquantifiable items or JSON object with object id ('id' attribute)
  # and quantity ('qty' attribute) for quantifiable items
  #
  # The 'json' parameters only accepts plain JS object values. Use numMin/numMax to allow multiple values 
  #
  # @param actual [Array] Array of execution parameter values
  # @param expected [Array] Array of parameter constraints
  # @param actor [Object] the actor on which the current rule is executed. Default to null
  # @param target [Object] the target on which the current rule is executed. Default to null
  # @param callback [Function] executed function when parameter were checked. Invoked with one argument:
  # @option callback err [String] null if value is correct, an error string otherwise
  checkParameters: (actual, expected, actor, target, callback) ->
    return callback null unless Array.isArray(expected) and expected.length > 0

    async.forEach expected
    , (param, next) ->
      # validate expected parameter
      unless 'object' is utils.type param
        return next "invalid expected parameter #{param}"
      unless 'string' is utils.type(param.name) and 'string' is utils.type param.type
        return next "invalid name or type within expected parameter #{JSON.stringify param}"

      # look for parameter value
      return next "#{param.name}Missing" unless actual?[param.name]?
      values =  if Array.isArray actual[param.name] then actual[param.name] else [actual[param.name]]

      # number of awaited occurences
      min = if param.numMin? then param.numMin else 1
      max = if param.numMax? then param.numMax else 1
      return next "#{param.name}TooFew #{min}" if values.length < min
      return next "#{param.name}TooMany #{max}" if values.length > max

      # value checking, that may be delayed if we need to resolve property possible values
      process = (possibles) ->
        for value in values
          # check value's type, except for 'object'
          unless param.type is 'object'
            err = checkPropertyType value, param 
            return next "typeError #{param.name} #{err}" if err?

          # specific types checks:
          switch param.type
            when 'integer', 'float'
              if 'number' is utils.type param.min
                return next "#{param.name}UnderMin #{param.min}" if value < param.min
              if 'number' is utils.type param.max
                return next "#{param.name}OverMax #{param.max}" if value > param.max
            when 'date', 'time', 'datetime'
              if 'date' is utils.type param.min
                return next "#{param.name}UnderMin #{param.min}" if value.getTime() < param.min.getTime()
              if 'date' is utils.type param.max
                return next "#{param.name}OverMax #{param.max}" if value.getTime() > param.max.getTime()
            when 'string'
              if Array.isArray param.within
                return next "#{param.name}UnallowedValue #{value}" unless value in param.within
              if 'string' is utils.type param.match
                return next "#{param.name}UnallowedValue" unless new RegExp(param.match).test value
            when 'object'
              # may be only strings (ids) or object with 'id' and 'qty' attribute
              id = null
              qty = null
              if 'string' is utils.type value
                id = value
              else if 'object' is utils.type(value) and 'string' is utils.type(value.id) and 'number' is utils.type(value.qty)
                id = value.id
                qty = value.qty
                return next "#{param.name}NegativeQuantity #{id}" if qty <= 0
              else
                return next "#{param.name}: #{JSON.stringify value} isn't a valid object id or id+qty"

              # check id is in possible values
              objValue = _.find possibles, (obj) -> id is obj?.id
              return next "#{param.name}UnallowedValue #{id}" unless objValue?

              # check quantity 
              return next "#{param.name}MissingQuantity #{id}" if objValue.type.quantifiable and qty is null
              return next "#{param.name}NotEnoughtFor #{id} #{qty}" if qty > objValue.quantity

        # everything was fine.
        next null

      return process() unless param.type is 'object'

      # for object, we need to check possible values
      if Array.isArray param.within
        possibles = []
        ids = []
        for obj in param.within 
          if utils.isA obj, Model
            possibles.push obj 
          else
            ids.push obj if 'string' is utils.type obj
        return process possibles if ids.length is 0

        # first look for items
        return require('../model/Item').findCached ids, (err, objs) ->
          return next "#{param.name}: failed to resolve possible items: #{err}" if err?
          ids = _.difference ids, _.pluck objs, 'id'
          possibles = possibles.concat objs
          return process possibles if ids.length is 0
          # then look for events
          require('../model/Event').findCached ids, (err, objs) ->
            return next "#{param.name}: failed to resolve possible events: #{err}" if err?
            ids = _.difference ids, _.pluck objs, 'id'
            possibles = possibles.concat objs
            process possibles 
      
      if 'object' is utils.type(param.property) and param.property.path? and param.property.from?
        return getProp (if param.property.from is 'target' then target else actor), param.property.path, (err, objs) ->
          return next "#{param.name}: failed to resolve possible values: #{err}" if err?
          process objs

      return next "missing 'within' constraint or invalid 'property' constraint (#{JSON.stringify param}) for parameter #{param.name}"

    , (err) -> 
      # end callback
      callback err or null

  # Walk through properties and replace linked object with their ids if necessary
  #
  # @param instance [Object] the processed instance
  # @param properties [Object] the propertes definition, a map index with property names and that contains for each property:
  # @option properties type [String] the awaited type. Could be: string, text, boolean, integer, float, date, array or object
  # @option properties def [Object] the default value. For array and objects, indicate the class of the awaited linked objects.
  # @param markModified [Boolean] true if the replacement need to be tracked as item modification. default to true
  processLinks: (instance, properties, markModified = true) ->
    for name, property of properties
      value = instance._doc[name]
      if property.type is 'object'
        if value isnt null and 'object' is utils.type(value) and value?.id?
          # Use internal model storage to avoid infinite call stack
          instance._doc[name] = value.id 
          instance.markModified name
      else if property.type is 'array'
        if 'array' is utils.type value
          for linked, i in value when 'object' is utils.type(linked) and linked?.id?
            value[i] = linked.id 
            instance.markModified name
          # filter null values. Use internal model storage to avoid infinite call stack
          instance._doc[name] = _.filter value, (obj) -> obj?

  # Returns the value of a given object's property, along the specified path.
  # Path may contains '.' to dive inside sub-objects, and '[]' to dive inside
  # arrays.
  # Unloaded sub-object will be loaded in waterfall.
  #
  # @param object [Object] root object on which property is read
  # @param path [String] path of the read property
  # @param callback [Function] extraction end function, invoked with 3 arguments
  # @option callback err [String] an error string, null if no error occured
  # @option callback value [Object] the property value.
  getProp: getProp

  # Populate the `modified` parameter array with models that have been modified.
  # For items and events, recursively check linked objects.
  # Can also handle Fields and Players
  #
  # @param obj [Object] root model that begins the analysis
  # @param modified [Array] array of already modified object, concatenated with found modified objects
  filterModified: (obj, modified, _parsed = []) ->
    # do not process if already known
    return if obj in _parsed
    _parsed.push obj
    # will be save if at least one path is modified
    if obj?.isModified?() or obj?.isNew
      modified.push obj
    if obj?._className is 'Player'
      # recurse if needed on characters
      module.exports.filterModified(value, modified, _parsed) for value in obj.characters when value? and 'string' isnt utils.type value
      return 
    # do not go further if not an obj
    return unless obj?._className is 'Item' or obj?._className is 'Event'
    properties = obj.type.properties
    for prop, def of properties
      if def.type is 'object'
        value = obj[prop]
        # recurse if needed on linked object that are resolved
        module.exports.filterModified(value, modified, _parsed) if value? and 'string' isnt utils.type value
      else if def.type is 'array'
        values = obj[prop]
        if values
          # recurse if needed on linked object that are resolved
          module.exports.filterModified(value, modified, _parsed) for value in values when value? and 'string' isnt utils.type value

  # Check id validity. Must be a string containing only alphanumerical characters and -.
  #
  # @param id [String] the checked id
  # @return true if the id is valid, false otherwise
  isValidId: (id) ->
    return false unless 'string' is utils.type id
    return false unless id.match /^[\w$-]+$/
    true

  # Evict models from cache that were loaded since a long time
  # Recursively triggers itself periodically. 
  # Inneffective if called multiple times: only the first call launches the period, and only the process exit will end it.
  #
  # @param caches [Object] inmemory caches.
  # Contains for each managed class (name as string) an associative array in which:
  # - key is model ids
  # - value is an object with "model" property (the model itself) "since" property (timestamp of last save)
  # @param frequency [Number] eviction check frequency in milliseconds
  # @param maxAge [Number] maximum age  check frequency in milliseconds
  evictModelCache: (caches, frequency, maxAge) ->
    return if eviction?
    evict = ->
      limit = new Date().getTime() - maxAge
      for className, models of caches
        # in a given model class, delete cached when since is bellow now - maxAge
        delete models[id] for id, cached of models when cached.since < limit
      # recursive execution at next start
      eviction = _.delay evict, frequency
    # first execution
    evict()