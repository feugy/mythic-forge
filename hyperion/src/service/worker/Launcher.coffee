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

cluster = require 'cluster'
# Not a master worker. Only usable in cluster mode as a worker
return if cluster.isMaster

pathUtils = require 'path'
modelWatcher = require('../../model/ModelWatcher').get()
Executable = require '../../model/Executable'
worker = require pathUtils.resolve __dirname, process.env.module
logger = require('../../logger').getLogger 'worker'

# init worker's rule cache
Executable.resetAll ->

# manage events received from master
process.on 'message', (msg) ->
  if msg?.event is 'change'
    # trigger the change as if it comes from the worker's own modelWatcher
    modelWatcher.emit.apply modelWatcher, ['change'].concat msg.args
  else if msg?.event is 'executableReset'
    # reloads the executable cache
    Executable.resetAll ->
  else if msg?.method of worker
    worker._method = msg.method
    # invoke the relevant worker method, adding a callback
    worker[msg.method].apply worker, (msg.args or []).concat (args...) ->
      # callback send back results to cluster master
      process.send method: msg.method, results: args

# manage worker unexpected failure
process.on 'uncaughtException', (err) ->
  err = if worker._errMsg? then worker._errMsg + err.stack else err.stack
  # an exception has been caught:
  logger.info "worker #{process.pid} caught unexpected exception: #{err}"
  process.send method: worker._method, results: [err]
  # let it fail: master will respawn it
  process.exit 1

# on change events, send them back to master
modelWatcher.on 'change', (args...) ->
  process.send event: 'change', args: [args].concat [process.pid]