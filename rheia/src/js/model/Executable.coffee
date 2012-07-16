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

define [
  'model/BaseModel'
  'model/sockets'
], (Base, sockets) ->

  # Client cache of executables.
  class Executables extends Base.Collection

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Executable'

  # Modelisation of a single Item Type.
  # Not wired to the server : use collections Items instead
  #
  class Executable extends Base.Model

    # Local cache for models.
    @collection = new Executables(@)

    # **private**
    # Class name of the managed model, for wiring to server and debugging purposes
    _className: 'Executable'

    # **private**
    # List of model attributes that are localized.
    _i18nAttributes: []

    # Provide a custom sync method to wire Types to the server.
    # Customize the update behaviour to rename if necessary.
    #
    # @param method [String] the CRUD method ("create", "read", "update", or "delete")
    # @param collection [Items] the current collection
    # @param args [Object] arguments. For executable renaming, please specify `newId` string value while updating.
    sync: (method, collection, args) =>
      switch method 
        when 'update' 
          # for update, we do not use 'save' method, but the 'saveAndRename' one.
          sockets.admin.once('saveAndRename-resp', (err) =>
            rheia.router.trigger('serverError', err, {method:'Executable.sync', details:method, id:@id}) if err?
          )
          sockets.admin.emit('saveAndRename', @toJSON(), args.newId)
        else super(method, collection, args)

  return Executable