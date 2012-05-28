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

        this._onUpdate = __bind(this._onUpdate, this);

        this._onSync = __bind(this._onSync, this);

        this.sync = __bind(this.sync, this);

        Items.__super__.constructor.call(this, model, options);
        sockets.game.on('consultMap-resp', this._onSync);
        sockets.updates.on('update', this._onUpdate);
      }

      Items.prototype.sync = function(method, instance, args) {
        switch (method) {
          case 'read':
            if (this._fetchRunning) {
              return;
            }
            this._fetchRunning = true;
            console.log("Consult map " + args.map + " between " + args.lowX + ":" + args.lowY + " and " + args.upX + ":" + args.upY);
            return sockets.game.emit('consultMap', args.map, args.lowX, args.lowY, args.upX, args.upY);
          default:
            throw new Error("Unsupported " + method + " operation on Items");
        }
      };

      Items.prototype._onSync = function(err, items) {
        if (this._fetchRunning) {
          this._fetchRunning = false;
          if (err != null) {
            return console.err("Fail to retrieve map content: " + err);
          }
          console.log("" + items.length + " map item(s) received");
          return this.add(items);
        }
      };

      Items.prototype._onUpdate = function(className, changes) {
        var item, key, value;
        if (className !== 'Item') {
          return;
        }
        item = this.get(changes._id);
        if (item == null) {
          return;
        }
        for (key in changes) {
          value = changes[key];
          if (key !== '_id' && key !== 'type') {
            item.set(key, value);
          }
        }
        return this.trigger('update', item);
      };

      Items.prototype.reset = function() {};

      return Items;

    })(Backbone.Collection);
    Item = (function(_super) {

      __extends(Item, _super);

      Item.name = 'Item';

      Item.collection = new Items(Item);

      Item.prototype.idAttribute = '_id';

      function Item(attributes) {
        this.equals = __bind(this.equals, this);
        Item.__super__.constructor.call(this, attributes);
      }

      Item.prototype.equals = function(other) {
        return this.id === (other != null ? other.id : void 0);
      };

      return Item;

    })(Backbone.Model);
    return Item;
  });

}).call(this);
