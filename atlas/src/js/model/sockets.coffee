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
  origin = "https://#{window.location.host}:443"
  
  return {
    # multiplexed socket for game method RPC
    game: io.connect "#{origin}/game", {secure: true}
    # multiplexed socket for game method RPC
    player: io.connect "#{origin}/player", {secure: true}
    # broadcast socket for database updates
    updates: io.connect "#{origin}/updates", {secure: true}
  }