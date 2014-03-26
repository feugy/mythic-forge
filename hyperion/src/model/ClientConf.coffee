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

# Define the schema for configuration values.
# locale will be the id, other values will be stored arbitrary
module.exports = conn.model 'clientConf', typeFactory 'ClientConf', 
  
  # configuration's values: plain yaml.
  values: 
    type: String
    default: -> ""
,
  middlewares:

    # Save middleware, to check that values are safe YAML
    save: (next) ->
      try
        yaml.safeLoad @_doc.values
        next()
      catch err
        # Not a valid YAML
        next new Error "YAML syntax error for 'values': #{err}"