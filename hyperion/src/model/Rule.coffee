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

# Game rules are constituted by two main functions:
#
#     canExecute(actor, target): Boolean
# which is invoked each time the rule engine needs to identify if the rule apply to a given situation
# 
#     execute(actor, target)
# which is invoked when the rule must be effectivly applied.
#
# `canExecute()` is intended to be invoked on server and client side, and must not modifiy anything.
class Rule

  # Rule's category
  category: ''

  # Active status. true by default
  active: true

  # All objects created or saved by the rule must be added to this array to be saved in database
  saved: []

  # All objects removed by the rule must be added to this array to be removed from database
  removed: []

  # Construct a rule, with a friendly name and a category.
  constructor: (@name, @category = '') ->
    @removed= []
    @saved= []
    @active= true
 
  # This method indicates wheter or not the rule apply to a given situation.
  # Beware: `canExecute`  is intended to be invoked on server and client side, thus, database access are not allowed.
  # This method must be overloaded by sub-classes
  #
  # @param actor [Item] the concerned actor
  # @param target [Item] the concerned target
  # @param callback [Function] called when the rule is applied, with two arguments:
  # @option callback err [String] error string. Null if no error occured
  # @option callback params [Array] array of awaited parameter (may be empty), or null/undefined if rule does not apply
  canExecute: (actor, target, callback) =>
    throw "#{module.filename}.canExecute() is not implemented yet !"

  # This method effectively contains the rule's logic.
  # It's invoked by the rule engine when the rule is applied.
  # Nothing can be saved directly in database, but target, acotr and their linked objects could be modified and will
  # be saved at the end of the execution.
  # This method must be overloaded by sub-classes
  #
  # @param actor [Item] the concerned actor
  # @param target [Item] the concerned target
  # @param params [Array] array (may be empty) of awaited parametes, specified by resolve.
  # @param callback [Function] called when the rule is applied, with one arguments:
  # @option callback err [String] error string. Null if no error occured
  # @option callback result [Object] an arbitrary result of this rule.
  execute: (actor, target, params, callback) =>
    throw "#{module.filename}.execute() is not implemented yet !"
        
module.exports = Rule