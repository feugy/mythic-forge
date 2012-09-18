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
  'socket.io'
  'async'
], (io, async) ->


  # different namespaces that ca be used to communicate qith server
  namespaces =
    game: null
    admin: null
    updates: null

    # the connect function will try to connect with server. 
    # 
    # @param token [String] the autorization token, obtained during authentication
    # @param callback [Function] invoked when all namespaces have been connected, with arguments:
    # @option callback err [String] the error detailed case, or null if no error occured
    connect: (token, callback) ->
      socket = io.connect conf.apiBaseUrl, {secure: true, query:"token=#{token}"}
      socket.on 'error', callback

      # On connection, retrieve current connected player immediately
      socket.emit 'getConnected', (err, player) =>
        # stores the token to allow re-connection
        rheia.player = player
        localStorage.setItem 'token', player.token

      # wire logout facilities
      rheia.router.on 'logout', => 
        localStorage.removeItem 'token'
        socket.emit 'logout'
        rheia.router.navigate 'login', trigger: true

      names = Object.keys namespaces
      names.splice names.indexOf('connect'), 1

      async.forEach names, (name, next) ->
        namespaces[name] = socket.of "/#{name}"
        namespaces[name].on 'connect', next
        namespaces[name].on 'connect_failed', next
      , (err) ->
        callback err

  namespaces