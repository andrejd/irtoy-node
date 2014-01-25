SerialPort      = require("serialport").SerialPort
list            = require("serialport").list
EventEmitter    = require('events').EventEmitter
async           = require 'async'


delay = (ms, func) -> setTimeout func, ms


class IRToy extends EventEmitter

    constructor: ->
        @dataCallBack   = null
        @codeParsed     = false
        @transmited     = 0
        @timeOut        = null
        @rBuff          = new Buffer [] # receive buffer
        @tBuff          = new Buffer [] #transmit buffer
        @parsers        = new Array()   # array of parsers
        @findIRToy()

    findIRToy: =>
        list (err, ports) =>
            for port in ports
                if port.pnpId == "usb-Dangerous_Prototypes_CDC_Test_00000001-if00"
                    @onFindIrToy port.comName

        # TODO: inform consumers that no device was found

    onFindIrToy: (serial_path) ->
        if serial_path?
            #console.log "IR Toy found on #{serial_path}"

            @sp = new SerialPort serial_path, {baudRate: 9600, buffersize: 512 }, false
            @sp.on 'open', @onOpen
            @sp.on 'data', (data) => if @dataCallBack? then @dataCallBack data
            #@sp.on 'close', -> console.log 'Exiting application!'
            #@sp.on 'error', -> console.log 'Serial port error!'

            @sp.open()

    registerParser:(parser) ->
        parser.on 'receive', @onReceive
        parser.on 'bad-data', () => @cleanUp(); @onOpen()

        @parsers.push parser


    onReceive:(ir_code) => @emit 'ircodereceived', ir_code

    # serial port event handlers
    onOpen: (args) =>

        that = @

        async.series [
            # Cancel transmit mode if IR Toy is in there
            (cb) ->
                that.writeData [0xFF, 0xFF]
                delay 25, -> cb null
            # Reset
            (cb) ->
                that.writeData [0x00, 0x00, 0x00, 0x00, 0x00]
                delay 20, -> cb null
            # Parser for received signals
            (cb) ->
                that.writeData 'S', that.handleReceivedData
                delay 20, -> cb null
        ],
        (err, results) ->
            #console.log "Here we go!"

    # TRANSMITTING

    transmit: (ircode) =>
        # first we need to find correct parser
        for parser in @parsers
            if parser.type == ircode.type
                @transmitCode parser.generate ircode.code, ircode.address
                break

    # TRANSMITTING IR COMMANDS
    transmitCode: (buffer) =>

        @tBuff = buffer
        @transmited = 0
        that = @

        async.series [
            (cb) ->
                that.writeData [0x00, 0x00, 0x00, 0x00, 0x00] # Reset
                delay 20, -> cb null
            (cb) ->
                that.writeData 'S' # Reset
                delay 20, -> cb null, Date.now()
            (cb) ->
                that.writeData [0x26] # Enable transmit handshake
                delay 10, -> cb null, Date.now()
            (cb) ->
                that.writeData [0x25] # Enable transmit notify on complete
                delay 10, -> cb null, Date.now()
            (cb) ->
                that.writeData [0x24] # Enable transmit byte count report
                delay 10, -> cb null, Date.now()
            # Enable transmit byte count report
            (cb) ->
                that.writeData [0x03], that.transmitHandshakeData
                delay 10, -> cb null, Date.now()
        ]

    transmitHandshakeData:(data) =>

        if parseInt(data[0]) == 62 && @tBuff.length > @transmited

            end = if @tBuff.length - @transmited > 62 then 62 else @tBuff.length - @transmited

            data2Send = @tBuff.slice @transmited, @transmited + end

            @transmited += data2Send.length

            @writeData data2Send, @transmitHandshakeData

        else

            for ch in data
                if ch in [67, 70] then @onOpen()


    # when data from IR TOy received, this handler is called
    handleReceivedData: (data) =>

        if @timeOut? then clearTimeout @timeOut

        if data.length == 3 && data.toString('ascii') == "S01"
            #console.log "Alles OK, lets roll ...."

        else if data.length == 2 && data.readUInt16BE(0) == 0xFFFF
            @cleanUp()

        else
            unless @codeParsed then @parseData data

        unless !@codeParsed
            @timeOut = setTimeout () =>
                @cleanUp()
            , 150

    parseData: (data) =>

        if @rBuff.length > 170 then @rBuff = new Buffer []

        @rBuff = Buffer.concat [@rBuff, data]

        #here we check if any of remotes recognise code
        for parser in @parsers
            if parser.parse @rBuff
                @codeParsed = true
                break

        if @codeParsed then @rBuff = new Buffer []


    cleanUp:() =>

        @timeOut = null
        @codeParsed = false
        @rBuff = new Buffer []

    writeData: (data, dataCB = null) =>

        @sp.flush()
        @sp.write data, (error, res) =>
            if error? then console.log error
            @dataCallBack = dataCB
            #console.log "Bytes written to IRToy #{res} #{Date.now()}"


module.exports = IRToy
