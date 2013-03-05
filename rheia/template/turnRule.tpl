TurnRule = require '../model/TurnRule'

# Your custom rule. 
# Always executed on server side.
# Set the active attribute to false to temporary disable it.
class CustomRule extends TurnRule

 
  # This method select a set of element on which execute will be applied.
  # Objects can be read directly from database, but modification is not allowed.
  #
  # @param callback [Function] called when the rule is applied, with two arguments:
  #   @param err [String] error string. Null if no error occured
  #   @param targets [Array] list of targeted object, null or empty if the rule does not apply.
  select: (callback) =>
    callback null, []

  # This method execute the rule on each targeted objects.
  # Nothing can be saved directly in database, but target and its linked objects could be modified and will
  # be saved at the end of the execution.
  # To remove an object, add it to the `removed` rule attribute (array).
  # To save a new or existing object not linked to actor or target, add it to the `saved` rule attribute (array).
  # This method must be overloaded by sub-classes
  #
  # @param target [Object] the targeted object
  # @param callback [Function] called when the rule is applied, with two arguments:
  #   @param err [String] error string. Null if no error occured
  execute: (target, callback) =>
    callback null
  
# A turn rule object must be exported. You can set its rank (default to 0)
module.exports = new CustomRule 0