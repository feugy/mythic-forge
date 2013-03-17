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
logger = require('../util/logger').getLogger 'model'

# Define the schema for map field types
FieldType = typeFactory 'FieldType',

  # descriptive image for this type.
  descImage:
    type: String

  # file path of field images, stored in an array
  images: 
    type: []
    default: -> []
, 
  hasImages: true

# Export the Class.
module.exports = conn.model 'fieldType', FieldType