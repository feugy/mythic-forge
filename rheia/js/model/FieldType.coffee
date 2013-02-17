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

define [
  'model/BaseModel'
], (Base) ->

  # Client cache of field types.
  class _FieldTypes extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'FieldType'

  # Modelisation of a single Field Type.
  # Not wired to the server : use collections FieldTypes instead
  #
  class FieldType extends Base.Model

    # Local cache for models.
    @collection: new _FieldTypes @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'FieldType'
      
    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['descImage', 'images']