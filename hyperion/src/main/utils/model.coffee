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