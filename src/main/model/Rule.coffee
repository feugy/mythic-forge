
# Game rules are constituted by two main functions:
#
#     canExecute(actor, target): Boolean
# which is invoked each time the rule engine needs to identify if the rule apply to a given situation
# 
#     execute(actor, target)
# which is invoked when the rule must be effectivly applied.
#
# `canExecute()`is intended to be invoked on server and client side, and must not modifiy anything.
class Rule

  # All objects created by the rule must be added to this array to be saved in database
  created: []

  # All objects removed by the rule must be added to this array to be removed from database
  removed: []

  # Construct a rule, with a friendly name.
  constructor: (@name) ->
    removed= []
    created= []
 
  # This method indicates wheter or not the rule apply to a given situation.
  # This method must be overloaded by sub-classes
  #
  # @param actor [Item] the concerned actor
  # @param target [Item] the concerned target
  # @param callback [Function] called when the rule is applied, with two arguments:
  #   @param err [String] error string. Null if no error occured
  #   @param apply [Boolean] true if the rule apply, false otherwise.
  canExecute: (actor, target, callback) =>
    throw "#{module.filename}.canExecute() is not implemented yet !"

  # This method effectively contains the rule's logic.
  # It's invoked by the rule engine when the rule is applied.
  # This method must be overloaded by sub-classes
  #
  # @param actor [Item] the concerned actor
  # @param target [Item] the concerned target
  # @param callback [Function] called when the rule is applied, with one arguments:
  #   @param err [String] error string. Null if no error occured
  #   @param result [Object] an arbitrary result of this rule.
  execute: (actor, target, callback) =>
    throw "#{module.filename}.execute() is not implemented yet !"

module.exports = Rule