# features
# control + tokenauth = websocket & player stuff
# history = show history page
# metadata = metadata
# section = sections
# trackalicious = tracking on front page
# motd = console.log
tidalstreamApp.config ($provide) ->
    $provide.factory 'tidalstreamService', ($rootScope, $location, $http, $q, $log, $modal, $timeout) ->
        obj =
            apiserver: null
            username: null
            password: null
            loggedIn: false
            loadingData: true
            featureList: {}
            sections: []
            players: {}
            playbackOutput:
                obj: null
                status: 'offline'
                type: null
            latestListing: null
            latestListingUrl: null
            searchSchemas: {}
            
            connectedToControl: false
            
            onWebsocketUpdate: null
            
            _metadataDB: null
            _websocket: null
            _connectStepBack: false
            
            ###
            PLAYER RELATED STUFF
            ###
            playerStop: (playerId) ->
                obj._sendToWebsocket 'stop', playerId
            
            playerNext: (playerId) ->
                obj._sendToWebsocket 'next', playerId
            
            playerPrevious: (playerId) ->
                obj._sendToWebsocket 'previous', playerId
            
            playerSetSpeed: (playerId, speed) ->
                obj.players[playerId].player.speed = speed
                obj._sendToWebsocket 'set_speed', playerId, speed: speed
            
            playerSeek: (playerId, timestamp) ->
                obj.players[playerId].player.current_time = timestamp
                obj._sendToWebsocket 'seek', playerId, time: timestamp
            
            playerPlayItem: (playerId, href) ->
                obj._sendToWebsocket 'open', playerId, url: href
            
            playerSetAudioStream: (playerId, trackId) ->
                obj._sendToWebsocket 'set_audio_stream', playerId, track_id: trackId
            
            playerSetSubtitle: (playerId, trackId) ->
                obj._sendToWebsocket 'set_subtitle', playerId, track_id: trackId
            
            _websocketPing: ->
                if obj._websocket and obj.connectedToControl
                    obj._websocket.send JSON.stringify
                        jsonrpc: "2.0"
                        method: 'ping'
            
            _connectToWebSocket: ->
                prepareReconnect = ->
                    console.log 'preparing', (if obj._connectStepBack then 10000 else 0)
                    $timeout (->
                        obj._connectToWebSocket()
                    ), (if obj._connectStepBack then 10000 else 0)
                    
                    obj._connectStepBack = true
                
                @_getToken().then ((token) ->
                    loginUrl = "ws#{ obj.featureList.control.slice 4 }/manage/websocket?token=#{ token }"
                    ws = obj._websocket = new WebSocket loginUrl
                    
                    ws.onopen = ->
                        obj._connectStepBack = false
                        $rootScope.$apply ->
                            obj.connectedToControl = true
                    
                    ws.onclose = ->
                        $rootScope.$apply ->
                            obj.connectedToControl = false
                        
                        prepareReconnect()
                    
                    ws.onerror = prepareReconnect
                    
                    ws.onmessage = obj._handleWebSocketMessage
                ), prepareReconnect
                    
            
            _disconnectToWebSocket: ->
                obj._websocket.close()
            
            _updatePlayerTime: ->
                for playerId, player of obj.players
                    if player.player? and player.player.length? and player.player.current_time?
                        player.player.current_time += player.player.speed * UPDATE_PLAYER_INTERVAL / 1000
            
            _getToken: ->
                deferred = $q.defer()
                
                $http.get "#{ obj.featureList.tokenauth }"
                    .success (data) ->
                        deferred.resolve data.token
                    .error (data, status, headers, config) ->
                        deferred.reject 'failed to fetch url'
                
                deferred.promise
            
            _handleWebSocketMessage: (e) ->
                data = JSON.parse e.data
                player_id = data.params.player_id
                
                switch data.method
                    when 'hello'
                        obj.players[player_id] = data.params
                        
                        defaultPlayer = obj.getDefaultPlayer()
                        
                        if obj.playbackOutput.type == 'player' and obj.playbackOutput.obj.player_id == player_id or defaultPlayer and defaultPlayer.type == 'player' and defaultPlayer.playerId == player_id
                            obj.playbackOutput.obj = obj.players[player_id]
                            obj.playbackOutput.status = 'online'
                        
                    when 'update'
                        for key, value of data.params.player
                            obj.players[player_id].player[key] = value
                    
                    when 'ended'
                        obj.players[player_id].player = {}
                    
                    when 'bye'
                        delete obj.players[player_id]
                        
                        if obj.playbackOutput.obj.player_id == player_id
                            obj.playbackOutput.status = 'offline'
                
                if obj.onWebsocketUpdate instanceof Function
                    obj.onWebsocketUpdate()
            
            _sendToWebsocket: (method, playerId, params) ->
                $log.debug 'Sending message to websocket', method, playerId, params
                if playerId == null
                    return
                
                cmd = 
                    jsonrpc: "2.0"
                    method: 'command'
                    params: params || {}
                
                cmd.params.player_id = playerId
                cmd.params.method = method
                
                obj._websocket.send JSON.stringify cmd
            
            ###
            METADATA RELATED STUFF
            ###
            _openMetadataDB: ->
                req = indexedDB.open DB_NAME, DB_VERSION
                req.onsuccess = (evt) ->
                    obj._metadataDB = @result;
            
                req.onupgradeneeded = (evt) ->
                    store = evt.currentTarget.result.createObjectStore DB_STORE_NAME, {keyPath: 'href'}
            
            _getObjectStore: (mode) ->
                tx = @_metadataDB.transaction DB_STORE_NAME, mode
                tx.objectStore DB_STORE_NAME
            
            downloadMetadata: (hrefs) ->
                for href in hrefs
                    $http.get href
                        .success (data) ->
                            store = obj._getObjectStore 'readwrite'
                            
                            if data instanceof Array
                                for item in data
                                    store.put item
                            else if 'title' of data
                                store.put data
            
            verifyMetadata: (data) ->
                i = 0
                store = @_getObjectStore 'readonly'
                
                missingMetadata = {}
                
                verifyMetadataResult = (href, data) ->
                    i--
                    category = href.split('/').slice(0, -1).join('/')
                    
                    if data == undefined
                        unless missingMetadata.hasOwnProperty(category)
                            missingMetadata[category] = []
                    
                        missingMetadata[category].push href
                    
                    if i == 0
                        for category, hrefs of missingMetadata
                            if hrefs.length > 50
                                obj.downloadMetadata [category]
                            else
                                obj.downloadMetadata hrefs
                    
                for item in data.result
                    if 'metadata' of item
                        i++
                        store.get item.metadata.href
                            .onsuccess = ((item) ->
                                (evt) ->
                                    verifyMetadataResult item.metadata.href, evt.target.result
                                )(item)
            
            ###
            MISC
            ###
            detectFeatures: -> # figure out what we can do
                $log.debug 'Detecting features'
                
                modalInstance = null
                modalData =
                    countdown: 30
                    errorMessage: null
                
                modalTimeout = $timeout (->
                        modalInstance = $modal.open
                            templateUrl: 'assets/partials/logging-in.html'
                            backdrop: 'static'
                            controller: 'LoggingInCtrl'
                            resolve:
                                data: ->
                                    modalData
                    ), 600
                
                $http.get @apiserver
                    .success (data) ->
                        if modalTimeout
                            $timeout.cancel(modalTimeout)
                        
                        for name, info of data
                            if info.rel == 'feature'
                                obj.featureList[name] = info.href
                            else if name == 'motd'
                                console.log 'The MOTD:', info
                        
                        for name, info of obj.featureList
                            $rootScope.$emit "feature-#{ name }"
                        
                        if modalInstance
                            modalInstance.dismiss()
                    .error (data, status, headers, config) ->
                        modalData.errorMessage = ['Failed to get features from APIServer. This means it is probably down!',
                                                  'You should try again later or contact your local system adminstrator']
            
            hasLoggedIn: (@apiserver, @username, @password) ->
                @loggedIn = true
                @detectFeatures()
                # need to check if there's a playback device saved in localstore we can use (only if we save username)
            
            hasLoggedOut: ->
                @loggedIn = false
                @apiserver = null
                @username = null
                @password = null
            
            listFolder: (path) ->
                unless path.indexOf('http') == 0
                    path = "#{ @apiserver }#{ path }"
                
                deferred = $q.defer()
                
                if path == @latestListingUrl
                    deferred.resolve @latestListing
                else
                    obj.loadingData = true
                    
                    $http.get path
                        .success (data) ->
                            obj.loadingData = false
                            
                            obj.latestListing = data
                            obj.latestListingUrl = path
                            
                            deferred.resolve data
                            
                            if Modernizr.indexeddb
                                obj.verifyMetadata data
                        .error ->
                            obj.loadingData = false
                
                deferred.promise
            
            getMetadata: (item) ->
                href = item.metadata.href
                unless href.indexOf('http') == 0
                    href = "#{ @apiserver }#{ path }"
                
                deferred = $q.defer()
                
                $http.get href
                    .success (data) ->
                        deferred.resolve data
                
                deferred.promise
            
            populateNavbar: ->
                @listFolder '/section'
                    .then (data) ->
                        obj.sections = data.result
            
            getSearchSchema: (section) ->
                deferred = $q.defer()
                
                if section of obj.searchSchemas
                    deferred.resolve obj.searchSchemas[section]
                else
                    $http.get "#{ obj.featureList.search }/#{ section }/?schema=1"
                        .success (data) ->
                            obj.searchSchemas[section] = data
                            deferred.resolve data
                
                deferred.promise
            
            doItemPlayback: (item) ->
                unless obj.playbackOutput.status == 'online'
                    $rootScope.$emit 'alert', 'warning', 'No player chosen, please choose a player before streaming.'
                    return
                
                obj.loadingData = true
                $http.post item.href
                    .success (data) ->
                        if data.status == 'error'
                            console.log 'show error msg on creating stream'
                        else
                            obj.loadingData = false
                            if obj.playbackOutput.type == 'download'
                                obj.openDownloadModal data
                            else if obj.playbackOutput.type == 'player'
                                playerPlayItem obj.playbackOutput.obj.player_id, data.href
            
            openDownloadModal: (item) ->
                modalInstance = $modal.open
                    templateUrl: 'assets/partials/download.html'
                    controller: 'DownloadCtrl'
                    resolve:
                        item: ->
                            item
            
            getDefaultPlayer: ->
                JSON.parse localStorage.getItem "defaultPlayer"
        
        if Modernizr.indexeddb
            obj._openMetadataDB()
        
        $rootScope.$watch (-> ($location.path())),
            (newValue, oldValue) ->
                unless obj.loggedIn or newValue == '/login'
                    if !!(localStorage.getItem "autoLogin")
                        apiserver = localStorage.getItem "apiserver"
                        username = localStorage.getItem "username"
                        password = localStorage.getItem "password"
                        obj.hasLoggedIn apiserver.replace(/\/+$/,'') , username, password
                    else
                        $location.path '/login'
        
        $rootScope.$on 'feature-section', ->
            obj.populateNavbar()
        
        $rootScope.$on 'feature-control', ->
            obj._connectToWebSocket()
        
        setInterval obj._updatePlayerTime, UPDATE_PLAYER_INTERVAL
        setInterval obj._websocketPing, WEBSOCKET_PING
        
        defaultPlayer = obj.getDefaultPlayer()
        if defaultPlayer.type == 'download'
            obj.playbackOutput =
                obj: null
                status: 'online'
                type: 'download'
        
        obj