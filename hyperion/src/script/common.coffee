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

moment = require 'moment'

# Time that can be manually controlled. Use moment until set to something els than null.
_time = null

module.exports = 

  # Consults current time or modifies it.
  # When modified, the time is blocked until reset to null.
  #
  # @param details [Array] if not set, returns the current time (blocked or not). If null,
  # set the current time to real current time. Otherwise, is the single argument of the 
  # MomentJS constructor (Array, String, Unix timestamp of Date)
  # @return a MomentJS object for the current time
  time: (details) ->
    if details is undefined
      # return set or current time
      if _time? then _time else moment()
    else if details is null
      # reset to current time
      _time = null
      moment()
    else
      # blocks time
      _time = moment details

  # Returns a random integer between two numbers
  # 
  # @param max [Number] maximum randomed number (included)
  # @param min [Number] minimal randomed number (included). Default to 0
  # @return the random number within this interval
  randomInt: (max, min = 0) ->
    min + Math.floor Math.random() * (max - min + 1)

  # Compute distance on an 3D isometric map
  # 
  # @param a [Object] first point coordinates (x, y)
  # @param b [Object] second point coordinates (x, y)
  # @return distance between two points
  isoDistance: (a, b) ->
    Math.sqrt(Math.pow(b.x - a.x,2)+Math.pow(b.y - a.y,2))
      
  # Compute distance on an hexagonal map
  # 
  # @param a [Object] first point coordinates (x, y)
  # @param b [Object] second point coordinates (x, y)
  # @return distance between two points
  hexDistance: (a, b) ->
    dx = b.x - a.x
    dy = b.y - a.y
    if dx < 0 and dy < 0 or dx >= 0 and dy >= 0
      Math.abs(dx + dy)
    else
      Math.max(Math.abs(dx), Math.abs(dy))