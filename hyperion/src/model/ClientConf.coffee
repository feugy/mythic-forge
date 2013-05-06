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
conn = require './connection'
{type} = require '../util/common'

# Define the schema for configuration values.
# locale will be the id, other values will be stored arbitrary
module.exports = conn.model 'clientConf', typeFactory 'ClientConf', 
  
  # configuration's values: plain json.
  values:
    type: {}
    default: -> {} # use a function to force instance variable
,
  middlewares:

    # Save original value for further comparisons.
    init: (next, conf) ->
      # store original value
      @__origvalues = JSON.stringify conf.values or {}
      next()

    # Save middleware, to check that no injection is done through values
    save: (next) ->
      try
        JSON.parse if 'string' is type @_doc.values then @_doc.values else JSON.stringify @_doc.values or {}
        next()
        # once saved, store new original value
        @__origvalues = JSON.stringify @_doc.values or {}
      catch err
        # Not a valid JSON
        next new Error "JSON syntax error for 'values': #{err}"