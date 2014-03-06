
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
var TurnRule,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; };

TurnRule = (function() {
  TurnRule.prototype.saved = [];

  TurnRule.prototype.removed = [];

  TurnRule.prototype.active = true;

  TurnRule.prototype.rank = 0;

  function TurnRule(rank) {
    this.rank = rank != null ? rank : 0;
    this.execute = __bind(this.execute, this);
    this.select = __bind(this.select, this);
    this.removed = [];
    this.saved = [];
  }

  TurnRule.prototype.select = function(callback) {
    throw "" + module.filename + ".select() is not implemented yet !";
  };

  TurnRule.prototype.execute = function(target, callback) {
    throw "" + module.filename + ".execute() is not implemented yet !";
  };

  return TurnRule;

})();

module.exports = TurnRule;
