
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
var EventEmitter, Timer, moment, _,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

moment = require('moment');

_ = require('underscore');

EventEmitter = require('events').EventEmitter;

Timer = (function(_super) {
  __extends(Timer, _super);

  Timer.prototype.stopped = false;

  function Timer() {
    this._step = __bind(this._step, this);
    this.set = __bind(this.set, this);
    this.current = __bind(this.current, this);
    this.stopped = false;
    this._offset = 0;
    this._time = moment();
    this._step();
  }

  Timer.prototype.current = function() {
    return this._time.clone().add('ms', this._offset);
  };

  Timer.prototype.set = function(newTime) {
    if (!moment.isMoment(newTime)) {
      newTime = moment(newTime);
      if (!newTime.isValid()) {
        newTime = moment();
      }
    }
    this._time = moment();
    this._offset = newTime.diff(this._time);
    return this.current();
  };

  Timer.prototype._step = function() {
    var now;
    now = moment();
    if (!this.stopped) {
      this._time.add('s', now.unix() - this._time.unix());
      this.emit('change', this.current());
    }
    return process.nextTick((function(_this) {
      return function() {
        return _.delay(_this._step, 1000 - now.milliseconds());
      };
    })(this));
  };

  return Timer;

})(EventEmitter);

module.exports = {
  timer: new Timer()
};
