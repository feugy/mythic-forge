###
  Copyright 2010~2014 Damien Feugas
  
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

  # Client cache of event types.
  class _EventTypes extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'EventType'

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections ItemTypes instead
  #
  class EventType extends Base.Model

    # Local cache for models.
    @collection: new _EventTypes @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'EventType'

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['descImage', 'properties', 'template']