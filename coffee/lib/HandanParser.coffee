util            = require 'util'
EventEmitter    = require('events').EventEmitter

# Handan Parser emits these events:
#
#   'receive' when code is parsed
#   'bad-data' when data can't be parsed
#



class HandanParser extends EventEmitter

    constructor: (@type = 'handan') ->
        @toggle = '1'


    parse:(buffer) =>
        #console.log 'Parsing RC-5 data'

        # if button was released on remote and pressed again then long gap
        # is present in incoming
        # buffer data and we need to chop off first two bytes
        if buffer[0] > 4 then buffer = buffer[2..]

        strm = (Math.floor(21.333 * buffer.readUInt16BE(i)) for i in [0..buffer.length - 1] by 2)

        codeHash =  '_'

        match = strm.every (element, index, array) ->

            if 600  < element < 1000
                if index % 2 > 0 then codeHash += '_' else codeHash += '#'

            else if 1000 < element < 2000
                if index % 2 > 0 then codeHash += '__' else codeHash += '##'

            else if 2000 < element
                codeHash += "|_" # break

            else return false

            return true

        # if all items are between boundaries
        if match

            commands = codeHash.split("|") # keys

            if commands.length > 1 and commands[0] == commands[1]

                c = commands[0]

                if c.length < 29 then return false

                if c.length == 29 then c += '_'

                code = ''

                for i in [0..c.length - 2] by 2
                    if c.substring(i, i+2) == '_#' then code += '1' else code += '0'

                #console.log c, code, code.length, parseInt(code, 2).toString(16)

                address = parseInt(code.substring(3,8),2)
                ircode  = parseInt(code.substring(8,15),2)

                @emit 'receive', {address:address, code:ircode, type:'handan'}
                #console.log {address:address, code:ircode, type:'handan'}
                return true

            else return false #not enough

        else return false # no match



    generate:(command, address) ->

        if @toggle == '0' then @toggle = '1' else @toggle = '0'

        codeBin = '0000000'.substring(0, 7 - command.toString(2).length) + command.toString(2)
        addrBin = '00000'.substring(0, 5 - address.toString(2).length) + address.toString(2)
        hdrBin  = '11' + @toggle

        c = hdrBin + addrBin + codeBin # 15 bytes

        str = ''
        for i in [0..c.length - 1]
            if c.substring(i, i+1) == '1' then str += '_#' else str += '#_'

        #console.log " "
        #console.log str, c, c.length, parseInt(c, 2).toString(16)

        strarr = str.substring(1)
                    .replace(/##/g,'1700 ')
                    .replace(/__/g,'1700 ')
                    .replace(/#/g,'860 ')
                    .replace(/_/g,'860 ')
                    .trim()
                    .split ' '

        buff = new Buffer strarr.length * 2

        buff.writeUInt16BE(Math.floor(val/21.333), i*2) for val, i in strarr

        Buffer.concat [buff, new Buffer [0xFF, 0xFF]]

module.exports = HandanParser