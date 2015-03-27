#!/usr/bin/env coffee
yargs = require "yargs"
express = require "express"
expressTimeout = require "express-timeout-header"
fs = require "fs"
morgan = require "morgan"
path = require "path"


args = yargs
    .usage("Usage: $0 [options]")
    .option("d",
        alias: "directory"
        demand: true
        describe: "The directory to server (this directory will become / in
            the HTTP server"
        requiresArg: true
        type: "string"
    )
    .help("h").alias("h", "help")
    .option("p",
        alias: "port"
        default: 8081
        describe: "The HTTP server port."
        requiresArg: true
    )
    .option("t",
        alias: "timeout"
        default: 10000
        describe: "The maximum timeout to apply (and the default timeout if
            --require-header is not set)."
        requireArg: true
    )
    .option("require-header",
        describe: "Require the Timeout header to be sent by a client to apply
            timeout logic. By default, the server applies the default timeout
            to all requests (to make it easier to test against unmodified
            clients), but this is probably a bad idea in most cases."
        type: "boolean"
    )
    .epilog("By Brendan Long <b.long@cablelabs.com> at CableLabs, Inc.")
    .argv


app = express()
app.use(morgan(":method :url served :status in :response-time ms"))
app.use(expressTimeout(args.directory,
    maxTimeout: args.timeout,
    requireHeader: args.requireHeader
))
app.use(express.static(args.directory))
app.listen(args.port)
