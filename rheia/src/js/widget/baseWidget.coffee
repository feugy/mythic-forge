###
  Copyright 2010,2011,2012 Damien Feugas
  
    This file is part of Mythic-Forge.

    Myth is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser Public License as published by
    the Free Software Foundation, either version 3 of the License, or
     at your option any later version.

    Myth is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser Public License for more details.

    You should have received a copy of the GNU Lesser Public License
###
'use strict'

define [
  'jquery'
  'jquery-ui'
],  ($) ->

  # This classes defines common methods to widgets.
  $.widget "rheia.baseWidget", 

    # Allows to set a widget option.
    #
    # @param key [String] the set option's key
    # @param value [Object] new value for this option
    setOption: (key, value) ->
      @_setOption(key, value)