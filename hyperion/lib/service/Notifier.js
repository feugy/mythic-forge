
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
var EventEmitter, NOTIF_EVT, Notifier, logger, _Notifier,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  __slice = [].slice;

logger = require('../util/logger').getLogger('service');

EventEmitter = require('events').EventEmitter;

NOTIF_EVT = 'notify';

module.exports = Notifier = (function() {
  var _instance;

  function Notifier() {}

  _instance = void 0;

  Notifier.get = function() {
    return _instance != null ? _instance : _instance = new _Notifier();
  };

  return Notifier;

})();

_Notifier = (function(_super) {
  __extends(_Notifier, _super);

  function _Notifier() {
    this.notify = __bind(this.notify, this);
    return _Notifier.__super__.constructor.apply(this, arguments);
  }

  _Notifier.prototype.NOTIFICATION = "" + NOTIF_EVT;

  _Notifier.prototype.notify = function() {
    var details, event;
    event = arguments[0], details = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    return this.emit.apply(this, [NOTIF_EVT, event].concat(details));
  };

  return _Notifier;

})(EventEmitter);
