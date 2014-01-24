IRToy         = require('../js/index.js').IRToy
NecParser     = require('../js/index.js').NecParser
HandanParser  = require('../js/index.js').HandanParser

toy         = new IRToy '/dev/ttyACM0'

nec         = new NecParser()
handan      = new HandanParser()

toy.registerParser nec
toy.registerParser handan

toy.on 'ircodereceived', (ir_code) ->
    console.log "Code received from IR remote", ir_code
    toy.transmit { address: 8403, code: 224, type: 'handan'}