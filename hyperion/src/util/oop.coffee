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

# Reuse of CoffeeScript OOP mechanisms
module.exports =

  # Allow to bind a given funciton to a scope
  #
  # @param func [Function] bound function
  # @param scope [Object] bound scope
  # @return the bound function
  bind: (func, scope) -> () -> func.apply scope, arguments

  # Create a class with optionnal parent
  #
  # @param constructor [Function] the function used as constructor for the created class
  # @param parent [Class] optionnal parent class
  # @param prototype [Object] object containing the created class's attributes and method
  # @return the extended class
  create: (constructor, parent, prototype) ->
    unless prototype?
      prototype = parent 
      parent = null

    # create the class
    clazz = ->
      @.__super__ = parent.prototype if parent?
      # bind methods to this instance
      for attr, value of @ when attr isnt 'constructor' and typeof value is 'function'
        @[attr] = module.exports.bind value, @
      
      constructor.apply @, arguments
      @

    # creates the inheritance prototype chain
    ctor = -> 
      @constructor = clazz
      @
    ctor.prototype = parent.prototype if parent?
    clazz.prototype = new ctor()

    clazz.__super__ = parent.prototype if parent?

    # copy methods and attributes into prototype
    clazz.prototype[key] = value for key, value of prototype

    clazz
