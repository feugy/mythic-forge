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

moment = require 'moment'
_ = require 'underscore'
EventEmitter = require('events').EventEmitter

# Timer object that will propagate time notifications and that manipulates current time
#
# Triggers `change` event when modified
class Timer extends EventEmitter

  # time may be stopped
  stopped : false

  constructor: ->
    @stopped = false
    # current timer offset relative to reference time
    @_offset = 0
    # reference time, initialized at now.
    @_time = moment()
    # plan the first execution
    @_step()

  # Returns a read only version of the current time
  #
  # @return the current time (read only)
  current: => 
    @_time.clone().add 'ms', @_offset

  # Set the current time. 
  # Reset to current time if not a valid time is used as parameter.
  #
  # @param newTime [Object] the new time. May be a moment object, any accepted moment() constructor arguments, or null
  # @return the current time (read only)
  set: (newTime) => 
    unless moment.isMoment newTime
      newTime = moment newTime
      newTime = moment() unless newTime.isValid()
    # compute new offset
    @_time = moment()
    @_offset = newTime.diff @_time
    # return current time
    @current()

  # **private**
  # time step, triggered each seconds
  _step: =>
    now = moment()
    unless @stopped
      # do not simply add one second: we may have missed several seconds if under heavy load. 
      @_time.add 's', now.unix()-@_time.unix()
      @emit 'change', @current()
    # we need to plan the next step
    process.nextTick =>
      _.delay @_step, 1000-now.milliseconds()

module.exports =
  timer: new Timer()