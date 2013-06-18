db = require('../helpers/db_connect_helper').db_connect()
fs = require 'fs'

permissions = {}
tokens = {}


## function checkToken (auth, tokens, callback)
## @auth {string} Field 'authorization' of request
## @tokens {tab} Tab which contains applications and their tokens
## @callback {function} Continuation to pass control back to when complete.
## Check if application is well authenticated
checkToken = (auth, callback) ->
    if auth isnt "undefined" and auth?
        # Recover username and password in field authorization
        auth = auth.substr(5, auth.length - 1)
        auth = new Buffer(auth, 'base64').toString('ascii')
        username = auth.split(':')[0]
        password = auth.split(':')[1]
        # Check if application is well authenticated
        if password isnt undefined and tokens[username] is password
            callback null, true, username
        else
            callback null, false, username
    else
        callback null, false, null


## function checkDocType (docType, app, callback)
## @docType {String} document's docType that application want manage
## @name {String} application's name
## @callback {function} Continuation to pass control back to when complete.
## Check if application can manage docType
module.exports.checkDocType = (auth, docType, callback) ->
    # Check if application is authenticated
    if process.env.NODE_ENV is "production" or process.env.NODE_ENV is "test"
        checkToken auth, (err, isAuthenticated, name) =>
            if isAuthenticated
                if docType?
                    docType = docType.toLowerCase()
                    # Check if application can manage docType
                    if permissions[name][docType]?
                        callback null, true, true
                    else if permissions[name]["all"]?
                        callback null, true, true
                    else
                        callback null, true, false
                else
                    callback null, true, true
            else
                callback null, false, false
    else
        callback null, true, true


## function checkProxy (auth, callback)
## @auth {String} Field 'authorization' i request header
##     Contains application name and password
## @callback {function} Continuation to pass control back to when complete.
## Check if application is proxy
## Useful for register and login requests
module.exports.checkProxyHome = (auth, callback) ->
    if process.env.NODE_ENV is "production" or process.env.NODE_ENV is "test"
        if auth isnt "undefined" and auth?
            # Recover username and password in field authorization
            auth = auth.substr(5, auth.length - 1)
            auth = new Buffer(auth, 'base64').toString('ascii')
            username = auth.split(':')[0]
            password = auth.split(':')[1]
            # Check if application is cozy-proxy
            if password isnt undefined and tokens[username] is password
                if username is "proxy" or username is "home"
                    callback null, true
                else
                    callback null, false
            else
                callback null, false
        else
            callback null, false
    else
        callback null, true


## function updatePermissons (body, callback)
## @body {Object} application:
##   * body.password is application token
##   * body.name is application name
##   * body.permissions is application permissions
## @callback {function} Continuation to pass control back to when complete.
## Update application permissions and token
module.exports.updatePermissions = (body, callback) ->
    if process.env.NODE_ENV is "production" or process.env.NODE_ENV is "test"
        if body.password?
            tokens[body.name] = body.password
        permissions[body.name] = {}
        if body.permissions?
            for docType, description of body.permissions
                permissions[body.name][docType.toLowerCase()] = description


## function initHomeProxy (callback)
## @callback {function} Continuation to pass control back to when complete
## Initialize tokens and permissions for Home and Proxy
initHomeProxy = (callback) ->
    token = process.env.TOKEN
    token = token.split('\n')[0]
    # Add home token and permissions
    tokens['home'] = token
    permissions.home =
        "application": "authorized"
        "notification": "authorized"
        "user": "authorized"
        "alarm": "authorized"
        "cozyinstance": "authorized"
        "encryptedkeys": "authorized"
    # Add proxy token and permissions
    tokens['proxy'] = token
    permissions.proxy =
        "user": "authorized"
        "cozyinstance": "authorized"
    callback null


## function initApplication (callback)
## @appli {Object} Application
## @callback {function} Continuation to pass control back to when complete
## Initialize tokens and permissions for application
initApplication = (appli, callback) ->
    if appli.state is "installed"
        tokens[appli.name] = appli.password
        if appli.permissions? and appli.permissions isnt null
            permissions[appli.name] = {}
            for docType, description of appli.permissions
                docType = docType.toLowerCase()
                permissions[appli.name][docType] = description
            callback null


## function init (callback)
## @callback {function} Continuation to pass control back to when complete.
## Initialize tokens which contains applications and their tokens
module.exports.init = (callback) ->
    # Read shared token
    if process.env.NODE_ENV is "production" or process.env.NODE_ENV is "test"
        initHomeProxy () ->
            # Add token and permissions for other started applications
            db.view 'application/all', (err, res) ->
                if err then callback new Error("Error in view")
                else
                    # Search application
                    res.forEach (appli) ->
                        initApplication appli, () ->
    callback tokens, permissions
