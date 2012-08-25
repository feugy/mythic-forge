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
  'i18n!nls/common'
  'underscore'
], (i18n, _) ->

  # The BaseValidator class defines commun mechanisms to create validators.
  #
  # Bound to a DOM node, it listens for changes, and validate the node inner value.
  # An error class can be set, and a string error returned.
  #
  # Subclasses must override the `_doValidation()` method.
  class BaseValidator
  
    # Friendly name for error messages
    name: ''

    # Event name(s) that triggers validations
    eventName: null

    # Css class appied in case of errors
    errorClass: 'validation-error'

    # last generated errors. read only.
    # will contains structures with attributes:
    # - error [String] the error type
    # - msg [String] a localized error
    errors: []

    # **private**
    # listened DOM node that contains validated value
    _node: null

    # **private**
    # function that extracts the validated value from the node
    _getValue: null

    # Constructor. Stores DOM node and bind to the event.
    #
    # @param attributes [Object] subclasses specific attributes. Allows to set them while creating a validator
    # @param name [String] field name for errors.
    # @param _node [jQuery] the concerned DOM node
    # @param eventName [String] the triggering event(s). 'change' by default
    # @param _getValue [Function] the value extraction function. use jQuery's val() by default. 
    constructor: (attributes, @name, @_node, @eventName = 'change', @_getValue = (node) -> return node.val()) ->
      for name, value of attributes
        @[name] = value
      @_errors = []
      @_node.on @eventName, @validate if @eventName?
    
    # Triggers validation. Could be invoked manually or on node change.
    # 
    #  @return array of generated erros, that may be empty if value is valid.
    validate: =>
      # does validation
      @_errors = @_doValidation @_getValue @_node
      # S'il y a une erreur, on remet la classe d'erreur
      @_node.toggleClass @errorClass, @_errors.length isnt 0
      return @_errors

    # Do not forget to invoke the dispose method to remove binding !
    dispose: =>
      @_node.unbind @eventName if @eventName?

    # **private**
    # the validation method that must be overriden by subclasses
    # @param value [String] the validated value
    # @return an array of errors. Empty if the value is valid.
    _doValidation: (value) =>
      throw new Error '_doValidation must be overriden by subclasses'

  # StringValidator class allows to check the existence of strings.
  class StringValidator extends BaseValidator

    # Error message when string is required and absent
    requiredError: i18n.validator.required

    # Error message when spaces are not allowed and presents
    spacesNotAllowedError: i18n.validator.spacesNotAllowed

    # value cannot be null, undefined or empty
    required: true

    # spaces are allowed.
    spacesAllowed: true

    # **private**
    # Validate the value's presence, and the use of spaces inside it
    _doValidation: (value) =>
      results = []
      if @required and !value
        results.push
          error: 'required'
          msg: _.sprintf @requiredError, @name
      
      if !@spacesAllowed and value and _.includeStr value, ' '
        results.push
          error: 'spacesNotAllowed'
          msg: _.sprintf @spacesNotAllowedError, @name
      
      results

  # RegexpValidator class allows to check arbitrary regular expression agains value.
  class RegexpValidator extends StringValidator

    # Error for unmatching value
    invalidError: i18n.validator.unmatch
    
    # regular expression.
    regexp: /^.*$/i

    # **private**
    # Validate the value's match against the regexp
    _doValidation: (value) =>
      results = super value
      if value and !value.match @regexp
        results.push
          error: 'invalid'
          msg: _.sprintf @invalidError, @name
        
      results

  # exports to outer world
  {
    Base: BaseValidator
    String: StringValidator
    Regexp: RegexpValidator
  }

  