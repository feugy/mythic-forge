
/*
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
 */
'use strict';
var Rule,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

Rule = (function() {
  Rule.prototype.category = '';

  Rule.prototype.active = true;

  Rule.prototype.saved = [];

  Rule.prototype.removed = [];

  function Rule(category) {
    this.category = category != null ? category : '';
    this.execute = __bind(this.execute, this);
    this.canExecute = __bind(this.canExecute, this);
    this.removed = [];
    this.saved = [];
  }

  Rule.prototype.canExecute = function(actor, target, context, callback) {
    throw "" + module.filename + ".canExecute() is not implemented yet !";
  };

  Rule.prototype.execute = function(actor, target, params, context, callback) {
    throw "" + module.filename + ".execute() is not implemented yet !";
  };

  return Rule;

})();

module.exports = Rule;
