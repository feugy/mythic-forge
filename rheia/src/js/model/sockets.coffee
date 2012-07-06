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
  'socket.io'
], (io) ->

  return {
    # multiplexed socket for game methods RPC
    game: io.connect("#{conf.apiBaseUrl}/game", {secure: true})

    # multiplexed socket for registration methods RPC
    player: io.connect("#{conf.apiBaseUrl}/player", {secure: true})

    # multiplexed socket for admin methods RPC
    admin: io.connect("#{conf.apiBaseUrl}/admin", {secure: true})

    # broadcast socket for database updates
    updates: io.connect("#{conf.apiBaseUrl}/updates", {secure: true})
  }
  