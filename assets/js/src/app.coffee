if Modernizr.indexeddb
    window.indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB
    window.IDBTransaction = window.IDBTransaction || window.webkitIDBTransaction || window.msIDBTransaction
    window.IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange

# constants, fu coffeescript
DB_NAME = 'tidalstream-metadata-storage'
DB_VERSION = 1
DB_STORE_NAME = 'metadata'
ENTRIES_PER_PAGE = 60
PAGINATION_CUTOFF = 5
UPDATE_PLAYER_INTERVAL = 100
WEBSOCKET_PING = 60000
KNOWN_LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'



tidalstreamApp = angular.module 'tidalstreamApp', [
    'ngRoute',
    'ui.bootstrap'
]

tidalstreamApp.config ($provide, $httpProvider) ->
    $provide.factory 'authenticationAndUrlHttpInterceptor', ($injector) ->
        request: (config) ->
            tidalstreamService = $injector.get 'tidalstreamService'
            if config.url.indexOf tidalstreamService.apiserver == 0
                config.headers.Authorization = 'Basic ' + btoa "#{ tidalstreamService.username }:#{ tidalstreamService.password }"
            
            config
    $httpProvider.interceptors.push 'authenticationAndUrlHttpInterceptor'

tidalstreamApp.config ($routeProvider) ->
    $routeProvider
        .when(
            '/login',
            templateUrl: 'assets/partials/login-dialog.html',
            controller: 'LoginCtrl'
        )
        .when(
            '/',
            templateUrl: 'assets/partials/front.html',
            controller: 'FrontCtrl'
        )
        .when(
            '/list',
            templateUrl: 'assets/partials/list.html',
            controller: 'ListCtrl' # listFromUrl
        )
        .otherwise(
            redirectTo: '/'
        )
# features
# control + tokenauth = websocket & player stuff
# history = show history page
# metadata = metadata
# section = sections
# trackalicious = tracking on front page
# motd = console.log
tidalstreamApp.config ($provide) ->
    $provide.factory 'tidalstreamService', ($rootScope, $location, $http, $q, $log, $interval, $modal) ->
        obj =
            apiserver: null
            username: null
            password: null
            loggedIn: false
            loadingData: true
            featureList: {}
            sections: []
            players: {}
            playbackOutput: 'download'
            latestListing: null
            latestListingUrl: null
            searchSchemas: {}
            
            connectedToControl: false
            
            onWebsocketUpdate: null
            
            _metadataDB: null
            _websocket: null
            
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
                @_getToken().then (token) ->
                    loginUrl = "ws#{ obj.featureList.control.slice 4 }/manage/websocket?token=#{ token }"
                    ws = obj._websocket = new WebSocket loginUrl
                    
                    ws.onopen = ->
                        $rootScope.$apply ->
                            obj.connectedToControl = true
                    
                    ws.onclose = ->
                        $rootScope.$apply ->
                            obj.connectedToControl = false
                    
                    ws.onmessage = obj._handleWebSocketMessage
            
            _disconnectToWebSocket: ->
                obj._websocket.close()
            
            _updatePlayerTime: ->
                for playerId, player of obj.players
                    if player.player? and player.player.length? and player.player.current_time?
                        player.player.current_time += player.player.speed * UPDATE_PLAYER_INTERVAL / 1000
            
            _getToken: ->
                deferred = $q.defer()
                
                $http.get "#{ obj.apiserver }/tokenauth/"
                    .success (data) ->
                        deferred.resolve data.token
                
                deferred.promise
            
            _handleWebSocketMessage: (e) ->
                data = JSON.parse e.data
                player_id = data.params.player_id
                
                switch data.method
                    when 'hello'
                        obj.players[player_id] = data.params
                        
                    when 'update'
                        for key, value of data.params.player
                            obj.players[player_id].player[key] = value
                    
                    when 'ended'
                        obj.players[player_id].player = {}
                    
                    when 'bye'
                        delete obj.players[player_id]
                        
                        if obj.playbackOutput.player_id == player_id
                            obj.playbackOutput = 'download'
                
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
                $http.get @apiserver
                    .success (data) ->
                        for name, info of data
                            if info.rel == 'feature'
                                obj.featureList[name] = info.href
                                
                                $rootScope.$emit "feature-#{ name }"
                                
                            else if name == 'motd'
                                console.log 'The MOTD:', info
            
            hasLoggedIn: (@apiserver, @username, @password) ->
                @loggedIn = true
                @detectFeatures()
            
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
                    $http.get "#{ obj.apiserver }/search/#{ section }/?schema=1"
                        .success (data) ->
                            obj.searchSchemas[section] = data
                            deferred.resolve data
                
                deferred.promise
            
            doItemPlayback: (item) ->
                obj.loadingData = true
                $http.post item.href
                    .success (data) ->
                        obj.loadingData = false
                        if obj.playbackOutput == 'download'
                            obj.openDownloadModal data
                        else
                            obj._sendToWebsocket 'open', obj.playbackOutput.player_id, url: data.href
            
            openDownloadModal: (item) ->
                modalInstance = $modal.open
                    templateUrl: 'assets/partials/download.html'
                    controller: 'DownloadCtrl'
                    resolve:
                        item: ->
                            item
        
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
        
        obj

tidalstreamApp.controller 'LoginCtrl', ($scope, $location, tidalstreamService) ->
    $scope.apiserver = localStorage.getItem "apiserver"
    $scope.username = localStorage.getItem "username"
    $scope.password = localStorage.getItem "password"
    $scope.rememberLogin = !!($scope.apiserver and $scope.username)
    $scope.rememberPassword = !!$scope.password
    $scope.autoLogin = !!(localStorage.getItem "autoLogin")
    
    $location.url $location.path()
    
    $scope.saveLoginInfo = ->
        localStorage.removeItem "apiserver"
        localStorage.removeItem "username"
        localStorage.removeItem "password"
        localStorage.removeItem "autoLogin"
        
        if $scope.rememberLogin
            localStorage.setItem "apiserver", $scope.apiserver
            localStorage.setItem "username", $scope.username
        
        if $scope.rememberPassword
            localStorage.setItem "password", $scope.password
            
            if $scope.autoLogin
                localStorage.setItem "autoLogin", true
        
        tidalstreamService.hasLoggedIn @apiserver.replace(/\/+$/,'') , @username, @password
        $location.path '/'

tidalstreamApp.controller 'FrontCtrl', ($scope, tidalstreamService) ->
    $scope.features = tidalstreamService.featureList

tidalstreamApp.controller 'NavbarCtrl', ($scope, $location, $modal, tidalstreamService) ->
    $scope.isLoggedIn = -> tidalstreamService.loggedIn
    $scope.getSections = -> tidalstreamService.sections
    $scope.getPlayers = -> tidalstreamService.players
    $scope.playbackOutput = -> tidalstreamService.playbackOutput
    $scope.getWebsocketStatus = -> tidalstreamService.connectedToControl
    $scope.tsService = tidalstreamService
    
    $scope.features = tidalstreamService.featureList
    
    $scope.changePath = (href) ->
        $location.url $location.path()
        
        $location.path '/list'
        $location.search 'url', href
    
    $scope.openPlayer = (player) ->
        modalInstance = $modal.open
            templateUrl: 'assets/partials/player.html'
            controller: 'PlayerCtrl'
            resolve:
                player: ->
                    player
    
    $scope.logout = ->
        localStorage.removeItem "apiserver"
        localStorage.removeItem "username"
        localStorage.removeItem "password"
        localStorage.removeItem "autoLogin"
        
        tidalstreamService.hasLoggedOut()
        
        $location.url '/login'
    
    $scope.setPlaybackOutput = ($event, target) ->
        tidalstreamService.playbackOutput = target
        $event.stopPropagation()
        $event.preventDefault()
    
    tidalstreamService.onWebsocketUpdate = ->
        $scope.$digest()

tidalstreamApp.controller 'ListCtrl', ($scope, $rootScope, $location, $q, tidalstreamService) ->
    $scope.listing = []
    $scope.pageToJumpTo = null
    $scope.letterPages = {}
    $scope.features = tidalstreamService.featureList
    
    $scope.data =
        showSearchBox: false
    
    args = $location.search()
    
    $scope.data =
        loading: true
        currentSorting: args.sort
        lastPage: 1
        currentPage: parseInt(args.page || 1)
    
    $scope.sortOptions = [
        {
            name: 'Date'
            value: '-date'
        }, {
            name: 'Name'
            value: 'name'
        }
    ]
    
    $scope.$watch "data.currentPage", (newValue, oldValue) ->
        if newValue != oldValue
            $scope.switchPage newValue
    
    $scope.jumpToPage = ->
        $scope.switchPage $scope.pageToJumpTo
    
    $scope.handleItem = (item) ->
        if item.rel == 'folder'
            $location.path '/list'
            $location.url $location.path()
            $location.search 'url', item.href
        else if item.rel == 'file'
            item.watched = Date.now()/1000
            tidalstreamService.doItemPlayback item
    
    $scope.switchPage = (pageNumber) ->
        $location.search 'page', pageNumber
    
    $scope.switchSorting = ->
        $location.search 'sort', $scope.data.currentSorting
    
    generateGroupedListing = (listing, itemsPerRow) ->
        retval = []
        
        i = 0
        while i * itemsPerRow < listing.length
            retval.push listing.slice i*itemsPerRow, (i+1)*itemsPerRow
            i++
        
        retval
    
    addMetadata = (listing) ->
        deferred = $q.defer()
        
        if Modernizr.indexeddb
            missingMetadata = []
            i = 0
            store = tidalstreamService._getObjectStore 'readonly'
            
            for item in listing
                unless 'metadata' of item
                    continue
                
                i++
                
                req = store.get item.metadata.href
                req.onsuccess = ((item) ->
                    (evt) ->
                        i--
                        value = evt.target.result
                        if value
                            $scope.$apply ->
                                item.metadata.result = value
                        else
                            missingMetadata.push item
                        
                        if i == 0
                            deferred.resolve missingMetadata
                )(item)
        else
            deferred.resolve (item for item in listing when 'metadata' of item)
        return deferred.promise
    
    flattenListing = (listing) ->
        retval = []
        
        if listing
            flatten = (items) ->
                for item in items
                    if 'result' of item
                        flatten item.result
                    else
                        retval.push item
            flatten listing
        
        retval
    
    generateLetterPages = (listing) ->
        $scope.letterPages = {'#': 0}
        i = 0
        for item in listing
            unless item.name
                continue
            
            firstLetter = item.name[0].toUpperCase()
            
            unless firstLetter in KNOWN_LETTERS
                continue
            
            unless firstLetter of $scope.letterPages
                $scope.letterPages[firstLetter] = Math.ceil(i / ENTRIES_PER_PAGE)
            
            i++
    
    $scope.listFolder = (url) ->
        tidalstreamService.listFolder url
            .then (data) ->
                $scope.data.loading = false
                $scope.title = data.title || data.name
                $scope.contentType = data.content_type || 'default'
                
                listing = flattenListing data.result
                
                if $scope.data.currentSorting
                    key = $scope.data.currentSorting
                    
                    reverse = false
                    if key[0] == '-'
                        key = key.slice 1
                        reverse = true
                    
                    listing.sort (a, b) ->
                        if a[key] > b[key]
                            return 1
                        else if a[key] < b[key]
                            return -1
                        else
                            return 0
                    
                    if reverse
                        listing.reverse()
                
                generateLetterPages listing
                $scope.data.lastPage = Math.ceil(listing.length / ENTRIES_PER_PAGE)
                
                listing = listing.slice ($scope.data.currentPage-1)*ENTRIES_PER_PAGE, $scope.data.currentPage*ENTRIES_PER_PAGE
                
                if tidalstreamService.featureList.metadata
                    addMetadata listing
                        .then (missingMetadata) ->
                            for item in missingMetadata
                                tidalstreamService.getMetadata item
                                    .then ((item) ->
                                        (metadata) ->
                                            if metadata
                                                item.metadata.result = metadata
                                        )(item)
                
                $scope.listing = listing
                $scope.groupedListing = generateGroupedListing $scope.listing, 6
    
    if args.url
        $scope.listFolder args.url

tidalstreamApp.controller 'SearchBoxCtrl', ($scope, $location, tidalstreamService) ->
    $scope.template = "assets/partials/search-loading.html"
    $scope.variables = {}
    $scope.schema = {}
    $scope.Math = window.Math
    
    currentUrl = $location.search().url
    section = currentUrl.split('/')[4]
    templateMap =
        anime: 'mal'
        tvshows: 'imdb'
        movies: 'imdb'
    
    tidalstreamService.getSearchSchema section
        .then (data) ->
            if data.status == 'error' or data.type not of templateMap
                $scope.template = 'assets/partials/search-nosearch.html'
            else
                $scope.schema = data.schema
                $scope.template = "assets/partials/search-#{ templateMap[data.type] }.html"
    
    $scope.doSearch = ->
        searchString = $scope.variables.q || ''
        console.log searchString
        
        for key, value of $scope.variables
            if key == 'q'
                continue
            
            if value instanceof Array
                for v in value
                    unless v
                        continue
                    
                    if v.indexOf(' ') > -1
                        v = "\"#{ v }\""
                    searchString += " #{ key }:#{ v }"
            else
                unless value
                    continue
                
                if value.indexOf(' ') > -1
                    value = "\"#{ value }\""
                searchString += " #{ key }:#{ value }"
            
        if searchString
            $location.url $location.path()
            $location.search 'url', "#{ tidalstreamService.featureList.search }/#{ section }/?q=#{ encodeURIComponent(searchString) }"
    
    $scope.toggleKey = (type, key) ->
        unless type of $scope.variables
            $scope.variables[type] = []
        
        index = $scope.variables[type].indexOf key
        if index > -1
            $scope.variables[type].splice index, 1
        else
            $scope.variables[type].push key
    
    $scope.isYear = (value) ->
        value.match(/^(19|20)\d{2}$/) != null
    
    $scope.not = (func) ->
        (item) ->
            !func item

tidalstreamApp.controller 'DownloadCtrl', ($scope, $interval, $modalInstance, tidalstreamService, item) ->
    $scope.item = item

tidalstreamApp.controller 'PlayerCtrl', ($scope, $interval, $modalInstance, tidalstreamService, player) ->
    $scope.player = player
    $scope.playerId = player.player_id
    $scope.currentPosition = '00:00:00'
    $scope.currentAudiostream = 0
    $scope.playbackOutput = -> tidalstreamService.playbackOutput
    $scope.setDefaultOutput = (player) ->
        tidalstreamService.playbackOutput = player
    
    $scope.$watch (-> tidalstreamService.players[$scope.playerId] ), (newValue, oldValue) ->
        if $scope.playerId of tidalstreamService.players
            $scope.player = tidalstreamService.players[$scope.playerId]
        else
            $scope.player = null
    
    $scope.fastBackward = ->
        tidalstreamService.playerPrevious $scope.player.player_id
    
    $scope.backward = ->
        speed = getSpeed -1
        unless speed == null
            tidalstreamService.playerSetSpeed $scope.player.player_id, speed
        
    $scope.stop = ->
        tidalstreamService.playerStop $scope.player.player_id
        
    $scope.pause = ->
        tidalstreamService.playerSetSpeed $scope.player.player_id, 0
        
    $scope.play = ->
        tidalstreamService.playerSetSpeed $scope.player.player_id, 1
        
    $scope.forward = ->
        speed = getSpeed 1
        unless speed == null
            tidalstreamService.playerSetSpeed $scope.player.player_id, speed
        
    $scope.fastForward = ->
        tidalstreamService.playerNext $scope.player.player_id
    
    $scope.seek = (timestamp) ->
        tidalstreamService.playerSeek $scope.player.player_id, timestamp
    
    $scope.calculateCurrentPosition = (event) ->
        $scope.currentPosition = calculateProgressbarTimestamp event
    
    $scope.clickOnProgressbar = (event) ->
        $scope.seek calculateProgressbarTimestamp event
    
    $scope.changedSubtitle = ->
        tidalstreamService.playerSetSubtitle $scope.player.player_id, $scope.player.player.current_subtitle
    
    $scope.changedAudioStream = ->
        tidalstreamService.playerSetAudioStream $scope.player.player_id, $scope.player.player.current_audiostream
    
    interval = $interval (->), 1000
    
    $scope.$originalDestroy = $scope.$destroy
    $scope.$destroy = ->
        $interval.cancel interval
        $scope.$originalDestroy()
    
    calculateProgressbarTimestamp = (event) ->
        width = event.currentTarget.offsetWidth
        clickWidth = event.offsetX
        (clickWidth / width) * $scope.player.player.length
    
    getSpeed = (direction) ->
        speeds = $scope.player.features.speed
        currentSpeed = $scope.player.player.speed
        
        unless 1 in speeds
            speeds.push 1
        
        speeds.sort (a, b) -> a-b
        index = speeds.indexOf(currentSpeed)
        
        if index == -1
            return null
        
        speeds[index+direction] || currentSpeed

tidalstreamApp.filter 'timespan', ->
    (input) ->
        input = parseInt input, 10
        hours = Math.floor input / 3600
        minutes = Math.floor input % 3600 / 60
        seconds = input % 60
        
        
        minutes = if minutes < 10 then '0' + minutes else minutes
        seconds = if seconds < 10 then '0' + seconds else seconds
        
        retval = "#{ minutes }:#{ seconds }"
        
        if hours > 0
            hours = if hours < 10 then '0' + hours else hours
            retval = "#{ hours }:#{ retval }"
        retval
