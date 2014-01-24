// Generated by CoffeeScript 1.6.3
var EventEmitter, HandanParser, util,
  __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

util = require('util');

EventEmitter = require('events').EventEmitter;

HandanParser = (function(_super) {
  __extends(HandanParser, _super);

  function HandanParser(type) {
    this.type = type != null ? type : 'handan';
    this.parse = __bind(this.parse, this);
    this.toggle = '1';
  }

  HandanParser.prototype.parse = function(buffer) {
    var address, c, code, codeHash, commands, i, ircode, match, strm, _i, _ref;
    if (buffer[0] > 4) {
      buffer = buffer.slice(2);
    }
    strm = (function() {
      var _i, _ref, _results;
      _results = [];
      for (i = _i = 0, _ref = buffer.length - 1; _i <= _ref; i = _i += 2) {
        _results.push(Math.floor(21.333 * buffer.readUInt16BE(i)));
      }
      return _results;
    })();
    codeHash = '_';
    match = strm.every(function(element, index, array) {
      if ((600 < element && element < 1000)) {
        if (index % 2 > 0) {
          codeHash += '_';
        } else {
          codeHash += '#';
        }
      } else if ((1000 < element && element < 2000)) {
        if (index % 2 > 0) {
          codeHash += '__';
        } else {
          codeHash += '##';
        }
      } else if (2000 < element) {
        codeHash += "|_";
      } else {
        return false;
      }
      return true;
    });
    if (match) {
      commands = codeHash.split("|");
      if (commands.length > 1 && commands[0] === commands[1]) {
        c = commands[0];
        if (c.length < 29) {
          return false;
        }
        if (c.length === 29) {
          c += '_';
        }
        code = '';
        for (i = _i = 0, _ref = c.length - 2; _i <= _ref; i = _i += 2) {
          if (c.substring(i, i + 2) === '_#') {
            code += '1';
          } else {
            code += '0';
          }
        }
        address = parseInt(code.substring(3, 8), 2);
        ircode = parseInt(code.substring(8, 15), 2);
        this.emit('receive', {
          address: address,
          code: ircode,
          type: 'handan'
        });
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  };

  HandanParser.prototype.generate = function(command, address) {
    var addrBin, buff, c, codeBin, hdrBin, i, str, strarr, val, _i, _j, _len, _ref;
    if (this.toggle === '0') {
      this.toggle = '1';
    } else {
      this.toggle = '0';
    }
    codeBin = '0000000'.substring(0, 7 - command.toString(2).length) + command.toString(2);
    addrBin = '00000'.substring(0, 5 - address.toString(2).length) + address.toString(2);
    hdrBin = '11' + this.toggle;
    c = hdrBin + addrBin + codeBin;
    str = '';
    for (i = _i = 0, _ref = c.length - 1; 0 <= _ref ? _i <= _ref : _i >= _ref; i = 0 <= _ref ? ++_i : --_i) {
      if (c.substring(i, i + 1) === '1') {
        str += '_#';
      } else {
        str += '#_';
      }
    }
    strarr = str.substring(1).replace(/##/g, '1700 ').replace(/__/g, '1700 ').replace(/#/g, '860 ').replace(/_/g, '860 ').trim().split(' ');
    buff = new Buffer(strarr.length * 2);
    for (i = _j = 0, _len = strarr.length; _j < _len; i = ++_j) {
      val = strarr[i];
      buff.writeUInt16BE(Math.floor(val / 21.333), i * 2);
    }
    return Buffer.concat([buff, new Buffer([0xFF, 0xFF])]);
  };

  return HandanParser;

})(EventEmitter);

module.exports = HandanParser;
