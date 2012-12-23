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

utils = require '../util/common'
_ = require 'underscore'

module.exports =

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
    # @return null if value is correct, an error string otherwise
  checkPropertyType: (value,  property) ->
    err = null

    # string and text: null or type is string
    checkString = (val) ->
      err = "'#{val}' isn't a valid string" unless val is null or 'string' is utils.type val

    # object: null or string (id) or object with a collection that have the good name.    
    checkObject = (val) ->
      err = "#{value} isn't a valid #{property.def}" unless val is null or 'string' is utils.type(val)  or
        ('object' is utils.type(val) and val?.collection?.name is property.def.toLowerCase()+'s')

    switch property.type 
      # integer: null or float = int value of a number/object
      when 'integer' then err = "#{value} isn't a valid integer" unless value is null or 
        ('number' is utils.type(value) and parseFloat(value, 10) is parseInt(value, 10))
      # foat: null or float value of a number/object
      when 'float' then err = "#{value} isn't a valid float" unless value is null or 
        ('number' is utils.type(value) and not isNaN parseFloat(value, 10))
      # boolean: null or value is false or true and not a string
      when 'boolean' 
        strVal = "#{value}".toLowerCase()
        err = "#{value} isn't a valid boolean" if value isnt null and
          ('string' is utils.type(value) or (strVal isnt 'true' and strVal isnt 'false'))
      # date : null or type is date
      when 'date' 
        if value isnt null
          if 'string' is utils.type value 
            err = "#{value} isn't a valid date" if isNaN new Date(value).getTime()
          else if 'date' isnt utils.type value
            err = "#{value} isn't a valid date" 
      when 'object' then checkObject value
      # array: array that contains object at each index.
      when 'array'
        if Array.isArray value
          checkObject obj for obj in value
        else 
          err = "#{value} isn't a valid array of #{property.def}"
      when 'string' then checkString value
      when 'text' then checkString value
      else err = "#{property.type} isn't a valid type"
    err

  # Check that passed parameters do not violate constraints of awaited parameters
  #
  # @param actual [Array] Array of execution parameter values
  # @param expected [Array] Array of parameter constraints
  # @return null if value is correct, an error string otherwise
  checkParameters: (actual, expected) ->
    err = null
    # TODO
    err

  # Walk through properties and replace linked object with their ids if necessary
  #
  # @param instance [Object] the processed instance
  # @param properties [Object] the propertes definition, a map index with property names and that contains for each property:
  # @option properties type [String] the awaited type. Could be: string, text, boolean, integer, float, date, array or object
  # @option properties def [Object] the default value. For array and objects, indicate the class of the awaited linked objects.
  # @param markModified [Boolean] true if the replacement need to be tracked as item modification. default to true
  processLinks: (instance, properties, markModified = true) ->
    for name, property of properties
      value = instance[name]
      if property.type is 'object'
        if value isnt null and 'object' is utils.type(value) and value?._id?
          instance[name] = value._id.toString() 
          instance.markModified name
      else if property.type is 'array'
        if 'array' is utils.type value
          for linked, i in value when 'object' is utils.type(linked) and linked?._id?
            value[i] = linked._id.toString() 
            instance.markModified name
          # filter null values
          instance[name] = _.filter value, (obj) -> obj?
