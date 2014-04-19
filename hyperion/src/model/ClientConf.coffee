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

typeFactory = require './typeFactory'
yaml = require 'js-yaml'
conn = require './connection'
{type} = require '../util/common'

# Parse YAML string source into _values model attributes.
#
# @param model [ClientConf] the concerned configuration
# @param source [String] the latestest YAML source
parseSource = (model, source) ->
  try
    model._values = yaml.safeLoad source or ""
  catch err
    # silently fails on error: save will be refused later
    model._values = {error: "invalid YAML source: #{err}"}

# Define the schema for configuration values.
# locale will be the id, other values will be stored arbitrary
ClientConf = typeFactory 'ClientConf', 

  # configuration's source: plain yaml.
  source: 
    type: String
    default: -> ""
    set: (value) ->
      # on each source modification, parse it and update values
      parseSource @, value
      value
,
  middlewares:

    # pre-init middleware: parse configuration
    #
    # @param next [Function] function that must be called to proceed with other middleware.
    # @param conf [ClientConf] the initialized configuration.
    init: (next, conf) ->
      parseSource @, @source
      next()

    # Save middleware, to check that values are safe YAML
    save: (next) ->
      try
        yaml.safeLoad @_doc.source
        next()
      catch err
        # Not a valid YAML
        next new Error "YAML syntax error for 'source': #{err}"

# Define a virtual getter on configuration parsed values, for immediate use.
ClientConf.virtual('values').get -> @_values or {}

module.exports = conn.model 'clientConf', ClientConf