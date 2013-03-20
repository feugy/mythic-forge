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

  # Client cache of client configurations.
  class _ClientConfs extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'ClientConf'

  # Modelisation of a single client configuration.
  # Not wired to the server : use collections ClientConfs instead
  class ClientConf extends Base.Model

    # Local cache for models.
    @collection: new _ClientConfs @

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'ClientConf'

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['values']
