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

  # Client cache of executables.
  class _Executables extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Executable'

    # **private**
    # Return handler of `list` server method. 
    # Store number of added executable to properly handle interdependencies
    #
    # @param reqId [String] client request id
    # @param err [String] error message. Null if no error occured
    # @param modelName [String] reminds the listed class name.
    # @param models [Array<Object>] raw models.
    _onGetList: (reqId, err, modelName, models) =>
      unless modelName isnt @_className or err?
        added = models.length 
        lastAdded = null
      super reqId, err, modelName, models

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections Items instead
  #
  class Executable extends Base.Model

    # Local cache for models.
    @collection: new _Executables @

    # Executable constructor, which init meta.
    #
    # @param attributes [Object] serialized attributes for this executable
    constructor: (attributes) ->
      attributes.meta or= {}
      super attributes

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Executable'

    # **private**
    # List of model attributes that are localized.
    _i18nAttributes: []

    # **private**
    # List of properties that must be defined in this instance.
    _fixedAttributes: ['content', 'path', 'meta', 'lang']