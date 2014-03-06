
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
module.exports = {
  bind: function(func, scope) {
    return function() {
      return func.apply(scope, arguments);
    };
  },
  create: function(constructor, parent, prototype) {
    var clazz, ctor, key, value;
    if (prototype == null) {
      prototype = parent;
      parent = null;
    }
    clazz = function() {
      var attr, value;
      if (parent != null) {
        this.__super__ = parent.prototype;
      }
      for (attr in this) {
        value = this[attr];
        if (attr !== 'constructor' && typeof value === 'function') {
          this[attr] = module.exports.bind(value, this);
        }
      }
      constructor.apply(this, arguments);
      return this;
    };
    ctor = function() {
      this.constructor = clazz;
      return this;
    };
    if (parent != null) {
      ctor.prototype = parent.prototype;
    }
    clazz.prototype = new ctor();
    if (parent != null) {
      clazz.__super__ = parent.prototype;
    }
    for (key in prototype) {
      value = prototype[key];
      clazz.prototype[key] = value;
    }
    return clazz;
  }
};
