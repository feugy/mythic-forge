(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor; child.__super__ = parent.prototype; return child; };

  define(['lib/backbone', 'model/sockets'], function(Backbone, sockets) {
    var Item, Items;
    Items = (function(_super) {

      __extends(Items, _super);

      Items.name = 'Items';

      Items.prototype._fetchRunning = false;

      function Items(model, options) {
        this.model = model;
        this.options = options;
        this.reset = __bind(this.reset, this);

        this._onSync = __bind(this._onSync, this);

        this.sync = __bind(this.sync, this);

        Items.__super__.constructor.call(this, model, options);
        sockets.game.on('consultMap-resp', this._onSync);
      }

      Items.prototype.sync = function(method, instance, args) {
        switch (method) {
          case 'read':
            if (this._fetchRunning) {
              return;
            }
            this._fetchRunning = true;
            console.log("Consult map items between " + args.lowX + ":" + args.lowY + " and " + args.upX + ":" + args.upY);
            return sockets.game.emit('consultMap', args.lowX, args.lowY, args.upX, args.upY);
          default:
            throw new Error("Unsupported " + method + " operation on Items");
        }
      };

      Items.prototype._onSync = function(err, items) {
        if (this._fetchRunning) {
          if (err != null) {
            return console.err("Fail to retrieve map content: " + err);
          }
          console.log("" + items.length + " map item(s) received");
          this.add(items);
          return this._fetchRunning = false;
        }
      };

      Items.prototype.reset = function() {};

      return Items;

    })(Backbone.Collection);
    Item = (function(_super) {

      __extends(Item, _super);

      Item.name = 'Item';

      Item.collection = new Items(Item);

      function Item(attributes) {
        Item.__super__.constructor.call(this, attributes);
        this.idAttribute = '_id';
      }

      return Item;

    })(Backbone.Model);
    return Item;
  });

}).call(this);
