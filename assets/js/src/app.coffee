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
    'ngTouch',
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












