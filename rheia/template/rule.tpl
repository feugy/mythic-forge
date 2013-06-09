Rule = require 'hyperion/model/Rule'

# Your custom rule.
# Set the active attribute to false to temporary disable it.
class CustomRule extends Rule

  # Rule test method: invoked each time a player try to test the rule (very often).
  # If rule apply, invoke the callback with an array (may be empty) of parameters.
  # May be executed at client-side.
  # 
  # @param actor [Item] the concerned actor
  # @param target [Item] the concerned target
  # @param context [Object] extra information on resolution context
  # @param callback [Function] called when the rule is applied, with two arguments:
  # @option callback err [String] error string. Null if no error occured
  # @option callback params [Array] array of awaited parameter (may be empty), or null/undefined if rule does not apply
  canExecute: (actor, target, context, callback) =>
    callback null, null

  # The rule execution method: actor and target may be modified, and will be automatically saved (as well as their modified linked object).
  # To remove an object, add it to the `removed` rule attribute (array).
  # To save a new or existing object not linked to actor or target, add it to the `saved` rule attribute (array).
  # You may return arbitrary results to the client by invoking the callback with a second parameter.
  # Validity of passed parameter is previously check: you do not need to test them.
  # Always executed at server side.
  #
  # @param actor [Item] the concerned actor
  # @param target [Item] the concerned target
  # @param params [Array] array (may be empty) of awaited parametes, specified by resolve.
  # @param callback [Function] called when the rule is applied, with one arguments:
  # @option callback err [String] error string. Null if no error occured
  # @option callback result [Object] an arbitrary result of this rule.
  execute: (actor, target, params, callback) =>
    callback null
  
# A rule object must be exported. You can set its category (constructor optionnal parameter)
module.exports = new CustomRule()