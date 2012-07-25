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

typeFactory = require './typeFactory'
conn = require './connection'
logger = require('../logger').getLogger 'model'

# Define the schema for map item types
Map = typeFactory 'Map', 
    # kind of map: square, diamond, hexagon
    kind: 
        type: String
        default: 'hexagon'
  , {strict:true, noDesc: true}
module.exports = conn.model 'map', Map
