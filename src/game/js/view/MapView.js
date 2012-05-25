(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  define(['lib/backbone', 'lib/jquery'], function(Backbone, $) {
    var MapView;
    MapView = (function(_super) {

      __extends(MapView, _super);

      MapView.name = 'MapView';

      function MapView(options) {
        this.render = __bind(this.render, this);
        options || (options = {});
        options.tagName || (options.tagName = 'span');
        MapView.__super__.constructor.call(this, options);
      }

      MapView.prototype.render = function() {
        var canvas, ctx, h, height, s, w, width, x, y, _i, _j, _ref;
        console.log("Render map view " + this.cid);
        s = 50;
        h = s * 2 * 0.8660254037844386;
        w = s * 2;
        width = w * 10 + 1;
        height = h * 9 + 1;
        canvas = $("<canvas width=\"" + width + "\" height=\"" + height + "\"></canvas>");
        this.$el.append(canvas);
        ctx = canvas[0].getContext('2d');
        for (y = _i = 0.5; 0.5 <= height ? _i <= height : _i >= height; y = _i += h) {
          for (x = _j = 0.5, _ref = w + s; 0.5 <= width ? _j <= width : _j >= width; x = _j += _ref) {
            ctx.moveTo(x + s * 0.5, y + h);
            ctx.lineTo(x, y + h * 0.5);
            ctx.lineTo(x + s * 0.5, y);
            ctx.lineTo(x + s * 1.5, y);
            ctx.lineTo(x + w, y + h * 0.5);
            ctx.moveTo(x + s * 1.5, y + h);
            ctx.lineTo(x + w, y + h * 0.5);
            ctx.lineTo(x + w + s, y + h * 0.5);
            ctx.lineTo(x + w + s * 1.5, y + h);
            ctx.lineTo(x + w + s, y + h * 1.5);
          }
        }
        ctx.strokeStyle = '#aaa';
        ctx.stroke();
        return this;
      };

      return MapView;

    })(Backbone.View);
    return MapView;
  });

}).call(this);
