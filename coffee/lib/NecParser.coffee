util            = require 'util'
EventEmitter    = require('events').EventEmitter

# Nec Parser emits these events:
#
#   'receive' when code is parsed
#   'bad-data' when data can't be parsed
#



class NecParser extends EventEmitter

    constructor: (@type = 'nec') ->

    parse:(buffer) =>

        codeBin = ''

        # we need at least 134 bytes for complete IR code
        # also if data is 255 some buffer overflow has happened

        if buffer.length < 134 #|| Math.max.apply(Math, buffer) == 255
            return false

        #strm = (getPulseLength(buffer, i) for i in [0..buffer.length-2] by 2)

        #strm =  (buffer.readUInt16BE(i) for i in [0..buffer.length-2] by 2)
        #console.log strm.toString(16).replace(/,/g,' '), "\n"

        for i in [0..buffer.length-4] by 2

            hi =  @_getPulseLength buffer, i
            lo =  @_getPulseLength buffer, i+2

            if 4200 < hi < 9000 && 4200 < lo < 4600 && i+4 < buffer.length-4

                codeBin = ''
                #console.log "Starting parsing buffer at #{i}, #{i+4} #{buffer.length}"
                for j in [i+4 ... buffer.length-4] by 4

                    hi = @_getPulseLength buffer, j
                    lo = @_getPulseLength buffer, j+2

                    if 2000 < hi + lo < 2500 then codeBin += '1'
                    else if 1000 < hi + lo < 1200 then codeBin += '0'
                    else
                        @emit 'bad-data'
                        return false
                        break
                break


        if codeBin.length >= 32

            address     = parseInt codeBin.substring(0,16), 2
            ircode      = parseInt codeBin.substring(16,24), 2
            ircodeInv   = parseInt codeBin.substring(24,32), 2


            #console.log address.toString(16), ircodeInv, ircode, @_getBinary(ircodeInv), @_getBinary ircode

            @emit 'receive', {address:address, code:ircode, type:'nec'}
            #console.log {address:address, code:ircode, type:'nec'}

            return true

        else
            return false

    generate:(cmd, address) =>

        codeBin     = '00000000'.substring(0, 8 - cmd.toString(2).length) + cmd.toString(2)
        commandInv  = (parseInt(cmd) ^ parseInt((new Array(cmd.toString(2).length+1)).join("1"),2)).toString(2)
        codeBinInv  = '00000000'.substring(0, 8 - commandInv.length) + commandInv
        addrBin     = '0000000000000000'.substring(0, 16 - address.toString(2).length) + address.toString(2)

        c = addrBin + codeBin + codeBinInv # 32 bytes

        buff = new Buffer c.length*4

        for i in [0...c.length]

            buff.writeUInt16BE(Math.floor(560/21.333), (i*4))  #high

            if c.charAt(i) == '0'
                buff.writeUInt16BE(Math.floor(560/21.333), (i*4)+2)  #low

            else
                buff.writeUInt16BE(Math.floor(1680/21.333), (i*4)+2)  #low

        Buffer.concat [Buffer([0x01,0xAC, 0x00, 0xD6]), buff, Buffer([0xFF, 0xFF])]

    # Private methods
    _getBinary: (val) ->
        '00000000'.substring(0, 8 - val.toString(2).length) + val.toString(2)

    _getPulseLength: (buffer, index) ->
        #console.log buffer.length, index
        if index > buffer.length - 2
            console.log "Index to large! #{index} for buff of #{buffer.length} "
            return 0
        else
            Math.floor(21.333 * buffer.readUInt16BE(index))

module.exports = NecParser