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
modelUtils = require '../util/model'
logger = require('../logger').getLogger 'model'

# Define the schema for event types
EventType = typeFactory 'EventType', 
  # descriptive image for this type.
  descImage:
    type: String
, 
  typeProperties: true
  instanceClass: 'Event'
  hasImages: true


# Adds an i18n `template` field
modelUtils.addI18n EventType, 'template'

# Export the Class.
module.exports = conn.model 'eventType', EventType