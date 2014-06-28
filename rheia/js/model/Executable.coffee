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
  'underscore'
  'model/BaseModel'
], (_, Base) ->

  # Client cache of executables.
  class _Executables extends Base.VersionnedCollection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Executable'

    # **private**
    # Global version changed: must refresh all models's content and history
    _onGlobalVersionChanged: =>
      # must wait a little for server to reset all executable
      _.delay => 
        @fetch()
      , 1500

    # **private**
    # Return handler of `list` server method. 
    #
    # @param reqId [String] client request id
    # @param err [String] error message. Null if no error occured
    # @param modelName [String] reminds the listed class name.
    # @param models [Array<Object>] raw models.
    _onGetList: (reqId, err, modelName, models) =>
      super reqId, err, modelName, models
      # fetch history for models that needs it, used during _onGlobalVersionChanged
      model.fetchHistory() for model in @models when model.history?

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections Items instead
  #
  class Executable extends Base.VersionnedModel

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
    _fixedAttributes: ['path', 'meta', 'lang']