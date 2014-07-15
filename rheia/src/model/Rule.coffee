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

define [], ->

  # Game rules on client side only contains the `canExecute()` part:
  class Rule
    
    # Activation status. True by default
    active: true

    # Construct a rule, with a category.
    constructor: (@category = '') ->
   
    # This method indicates wheter or not the rule apply to a given situation.
    # Beware: `canExecute`  is intended to be invoked on server and client side, thus, database access are not allowed.
    # This method must be overloaded by sub-classes
    #
    # @param actor [Item] the concerned actor
    # @param target [Item] the concerned target
    # @param callback [Function] called when the rule is applied, with two arguments:
    #   @param err [String] error string. Null if no error occured
    #   @param apply [Boolean] true if the rule apply, false otherwise.
    canExecute: (actor, target, callback) =>
      throw "#{module.filename}.canExecute() is not implemented yet !"