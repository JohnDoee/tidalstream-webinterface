// Generated by CoffeeScript 1.7.1
(function() {
  var DB_NAME, DB_STORE_NAME, DB_VERSION, ENTRIES_PER_PAGE, KNOWN_LETTERS, PAGINATION_CUTOFF, UPDATE_PLAYER_INTERVAL, WEBSOCKET_PING, tidalstreamApp,
    __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  if (Modernizr.indexeddb) {
    window.indexedDB = window.indexedDB || window.mozIndexedDB || window.webkitIndexedDB || window.msIndexedDB;
    window.IDBTransaction = window.IDBTransaction || window.webkitIDBTransaction || window.msIDBTransaction;
    window.IDBKeyRange = window.IDBKeyRange || window.webkitIDBKeyRange || window.msIDBKeyRange;
  }

  DB_NAME = 'tidalstream-metadata-storage';

  DB_VERSION = 1;

  DB_STORE_NAME = 'metadata';

  ENTRIES_PER_PAGE = 60;

  PAGINATION_CUTOFF = 5;

  UPDATE_PLAYER_INTERVAL = 100;

  WEBSOCKET_PING = 60000;

  KNOWN_LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

  tidalstreamApp = angular.module('tidalstreamApp', ['ngRoute', 'ngTouch', 'ui.bootstrap']);

  tidalstreamApp.config(function($provide, $httpProvider) {
    $provide.factory('authenticationAndUrlHttpInterceptor', function($injector) {
      return {
        request: function(config) {
          var tidalstreamService;
          tidalstreamService = $injector.get('tidalstreamService');
          if (config.url.indexOf(tidalstreamService.apiserver === 0)) {
            config.headers.Authorization = 'Basic ' + btoa("" + tidalstreamService.username + ":" + tidalstreamService.password);
          }
          return config;
        }
      };
    });
    return $httpProvider.interceptors.push('authenticationAndUrlHttpInterceptor');
  });

  tidalstreamApp.config(function($routeProvider) {
    return $routeProvider.when('/login', {
      templateUrl: 'assets/partials/login-dialog.html',
      controller: 'LoginCtrl'
    }).when('/', {
      templateUrl: 'assets/partials/front.html',
      controller: 'FrontCtrl'
    }).when('/list', {
      templateUrl: 'assets/partials/list.html',
      controller: 'ListCtrl'
    }).otherwise({
      redirectTo: '/'
    });
  });

  tidalstreamApp.controller('AlertCtrl', function($scope, $rootScope, tidalstreamService) {
    $scope.data = {
      alerts: []
    };
    $scope.closeAlert = function(index) {
      return $scope.data.alerts.splice(index, 1);
    };
    return $rootScope.$on('alert', function($event, type, msg) {
      return $scope.data.alerts.push({
        type: type,
        msg: msg
      });
    });
  });

  tidalstreamApp.controller('DownloadCtrl', function($scope, $interval, $modalInstance, tidalstreamService, item) {
    return $scope.item = item;
  });

  tidalstreamApp.controller('FrontCtrl', function($scope, tidalstreamService) {
    return $scope.features = tidalstreamService.featureList;
  });

  tidalstreamApp.controller('ListCtrl', function($scope, $rootScope, $location, $q, tidalstreamService) {
    var addMetadata, args, flattenListing, generateGroupedListing, generateLetterPages;
    $scope.listing = [];
    $scope.pageToJumpTo = null;
    $scope.letterPages = {};
    $scope.features = tidalstreamService.featureList;
    $scope.data = {
      showSearchBox: false
    };
    args = $location.search();
    $scope.data = {
      loading: true,
      currentSorting: args.sort,
      lastPage: 1,
      currentPage: parseInt(args.page || 1)
    };
    $scope.sortOptions = [
      {
        name: 'Date',
        value: '-date'
      }, {
        name: 'Name',
        value: 'name'
      }
    ];
    $scope.$watch("data.currentPage", function(newValue, oldValue) {
      if (newValue !== oldValue) {
        return $scope.switchPage(newValue);
      }
    });
    $scope.jumpToPage = function() {
      return $scope.switchPage($scope.pageToJumpTo);
    };
    $scope.handleItem = function(item) {
      if (item.rel === 'folder') {
        $location.path('/list');
        $location.url($location.path());
        return $location.search('url', item.href);
      } else if (item.rel === 'file') {
        item.watched = Date.now() / 1000;
        return tidalstreamService.doItemPlayback(item);
      }
    };
    $scope.switchPage = function(pageNumber) {
      return $location.search('page', pageNumber);
    };
    $scope.switchSorting = function() {
      return $location.search('sort', $scope.data.currentSorting);
    };
    generateGroupedListing = function(listing, itemsPerRow) {
      var i, retval;
      retval = [];
      i = 0;
      while (i * itemsPerRow < listing.length) {
        retval.push(listing.slice(i * itemsPerRow, (i + 1) * itemsPerRow));
        i++;
      }
      return retval;
    };
    addMetadata = function(listing) {
      var deferred, i, item, missingMetadata, req, store, _i, _len;
      deferred = $q.defer();
      if (Modernizr.indexeddb) {
        missingMetadata = [];
        i = 0;
        store = tidalstreamService._getObjectStore('readonly');
        for (_i = 0, _len = listing.length; _i < _len; _i++) {
          item = listing[_i];
          if (!('metadata' in item)) {
            continue;
          }
          i++;
          req = store.get(item.metadata.href);
          req.onsuccess = (function(item) {
            return function(evt) {
              var value;
              i--;
              value = evt.target.result;
              if (value) {
                $scope.$apply(function() {
                  return item.metadata.result = value;
                });
              } else {
                missingMetadata.push(item);
              }
              if (i === 0) {
                return deferred.resolve(missingMetadata);
              }
            };
          })(item);
        }
      } else {
        deferred.resolve((function() {
          var _j, _len1, _results;
          _results = [];
          for (_j = 0, _len1 = listing.length; _j < _len1; _j++) {
            item = listing[_j];
            if ('metadata' in item) {
              _results.push(item);
            }
          }
          return _results;
        })());
      }
      return deferred.promise;
    };
    flattenListing = function(listing) {
      var flatten, retval;
      retval = [];
      if (listing) {
        flatten = function(items) {
          var item, _i, _len, _results;
          _results = [];
          for (_i = 0, _len = items.length; _i < _len; _i++) {
            item = items[_i];
            if ('result' in item) {
              _results.push(flatten(item.result));
            } else {
              _results.push(retval.push(item));
            }
          }
          return _results;
        };
        flatten(listing);
      }
      return retval;
    };
    generateLetterPages = function(listing) {
      var firstLetter, i, item, _i, _len, _results;
      $scope.letterPages = {
        '#': 0
      };
      i = 0;
      _results = [];
      for (_i = 0, _len = listing.length; _i < _len; _i++) {
        item = listing[_i];
        if (!item.name) {
          continue;
        }
        firstLetter = item.name[0].toUpperCase();
        if (__indexOf.call(KNOWN_LETTERS, firstLetter) < 0) {
          continue;
        }
        if (!(firstLetter in $scope.letterPages)) {
          $scope.letterPages[firstLetter] = Math.ceil(i / ENTRIES_PER_PAGE);
        }
        _results.push(i++);
      }
      return _results;
    };
    $scope.listFolder = function(url) {
      return tidalstreamService.listFolder(url).then(function(data) {
        var key, listing, reverse;
        $scope.data.loading = false;
        $scope.title = data.title || data.name;
        $scope.contentType = data.content_type || 'default';
        listing = flattenListing(data.result);
        if ($scope.data.currentSorting) {
          key = $scope.data.currentSorting;
          reverse = false;
          if (key[0] === '-') {
            key = key.slice(1);
            reverse = true;
          }
          listing.sort(function(a, b) {
            if (a[key] > b[key]) {
              return 1;
            } else if (a[key] < b[key]) {
              return -1;
            } else {
              return 0;
            }
          });
          if (reverse) {
            listing.reverse();
          }
        }
        generateLetterPages(listing);
        $scope.data.lastPage = Math.ceil(listing.length / ENTRIES_PER_PAGE);
        listing = listing.slice(($scope.data.currentPage - 1) * ENTRIES_PER_PAGE, $scope.data.currentPage * ENTRIES_PER_PAGE);
        if (tidalstreamService.featureList.metadata) {
          addMetadata(listing).then(function(missingMetadata) {
            var item, _i, _len, _results;
            _results = [];
            for (_i = 0, _len = missingMetadata.length; _i < _len; _i++) {
              item = missingMetadata[_i];
              _results.push(tidalstreamService.getMetadata(item).then((function(item) {
                return function(metadata) {
                  if (metadata) {
                    return item.metadata.result = metadata;
                  }
                };
              })(item)));
            }
            return _results;
          });
        }
        $scope.listing = listing;
        return $scope.groupedListing = generateGroupedListing($scope.listing, 6);
      });
    };
    if (args.url) {
      return $scope.listFolder(args.url);
    }
  });

  tidalstreamApp.controller('LoginCtrl', function($scope, $location, tidalstreamService) {
    $scope.apiserver = localStorage.getItem("apiserver");
    $scope.username = localStorage.getItem("username");
    $scope.password = localStorage.getItem("password");
    $scope.rememberLogin = !!($scope.apiserver && $scope.username);
    $scope.rememberPassword = !!$scope.password;
    $scope.autoLogin = !!(localStorage.getItem("autoLogin"));
    $location.url($location.path());
    return $scope.saveLoginInfo = function() {
      localStorage.removeItem("apiserver");
      localStorage.removeItem("username");
      localStorage.removeItem("password");
      localStorage.removeItem("autoLogin");
      if ($scope.rememberLogin) {
        localStorage.setItem("apiserver", $scope.apiserver);
        localStorage.setItem("username", $scope.username);
      }
      if ($scope.rememberPassword) {
        localStorage.setItem("password", $scope.password);
        if ($scope.autoLogin) {
          localStorage.setItem("autoLogin", true);
        }
      }
      tidalstreamService.hasLoggedIn(this.apiserver.replace(/\/+$/, ''), this.username, this.password);
      return $location.path('/');
    };
  });

  tidalstreamApp.controller('LoggingInCtrl', function($scope, $modalInstance, $interval, data) {
    var countdown, doCountdown;
    $scope.data = data;
    doCountdown = function() {
      return $scope.data.countdown -= 1;
    };
    return countdown = $interval(doCountdown, 1000, $scope.data.countdown);
  });

  tidalstreamApp.controller('NavbarCtrl', function($scope, $location, $modal, tidalstreamService) {
    var savePlaybackOutput;
    $scope.isLoggedIn = function() {
      return tidalstreamService.loggedIn;
    };
    $scope.getSections = function() {
      return tidalstreamService.sections;
    };
    $scope.getPlayers = function() {
      return tidalstreamService.players;
    };
    $scope.playbackOutput = tidalstreamService.playbackOutput;
    $scope.getWebsocketStatus = function() {
      return tidalstreamService.connectedToControl;
    };
    $scope.tsService = tidalstreamService;
    $scope.features = tidalstreamService.featureList;
    $scope.changePath = function(href) {
      $location.url($location.path());
      $location.path('/list');
      return $location.search('url', href);
    };
    $scope.openPlayer = function(player) {
      var modalInstance;
      return modalInstance = $modal.open({
        templateUrl: 'assets/partials/player.html',
        controller: 'PlayerCtrl',
        resolve: {
          player: function() {
            return player;
          }
        }
      });
    };
    $scope.logout = function() {
      localStorage.removeItem("apiserver");
      localStorage.removeItem("username");
      localStorage.removeItem("password");
      localStorage.removeItem("autoLogin");
      tidalstreamService.hasLoggedOut();
      return $location.url('/login');
    };
    savePlaybackOutput = function(type, target) {
      var currentPlayer;
      if (localStorage.getItem("apiserver")) {
        currentPlayer = {
          type: type
        };
        if (type === 'player') {
          currentPlayer.playerId = target.player_id;
        }
        return localStorage.setItem("defaultPlayer", JSON.stringify(currentPlayer));
      }
    };
    $scope.setPlaybackOutput = function($event, type, target) {
      tidalstreamService.playbackOutput.obj = target;
      tidalstreamService.playbackOutput.type = type;
      tidalstreamService.playbackOutput.status = 'online';
      savePlaybackOutput(type, target);
      $event.stopPropagation();
      return $event.preventDefault();
    };
    return tidalstreamService.onWebsocketUpdate = function() {
      return $scope.$digest();
    };
  });

  tidalstreamApp.controller('PlayerCtrl', function($scope, $interval, $modalInstance, tidalstreamService, player) {
    var calculateProgressbarTimestamp, getSpeed, interval;
    $scope.player = player;
    $scope.playerId = player.player_id;
    $scope.currentPosition = '00:00:00';
    $scope.currentAudiostream = 0;
    $scope.$watch((function() {
      return tidalstreamService.players[$scope.playerId];
    }), function(newValue, oldValue) {
      if ($scope.playerId in tidalstreamService.players) {
        return $scope.player = tidalstreamService.players[$scope.playerId];
      } else {
        return $scope.player = null;
      }
    });
    $scope.fastBackward = function() {
      return tidalstreamService.playerPrevious($scope.player.player_id);
    };
    $scope.backward = function() {
      var speed;
      speed = getSpeed(-1);
      if (speed !== null) {
        return tidalstreamService.playerSetSpeed($scope.player.player_id, speed);
      }
    };
    $scope.stop = function() {
      return tidalstreamService.playerStop($scope.player.player_id);
    };
    $scope.pause = function() {
      return tidalstreamService.playerSetSpeed($scope.player.player_id, 0);
    };
    $scope.play = function() {
      return tidalstreamService.playerSetSpeed($scope.player.player_id, 1);
    };
    $scope.forward = function() {
      var speed;
      speed = getSpeed(1);
      if (speed !== null) {
        return tidalstreamService.playerSetSpeed($scope.player.player_id, speed);
      }
    };
    $scope.fastForward = function() {
      return tidalstreamService.playerNext($scope.player.player_id);
    };
    $scope.seek = function(timestamp) {
      return tidalstreamService.playerSeek($scope.player.player_id, timestamp);
    };
    $scope.calculateCurrentPosition = function(event) {
      return $scope.currentPosition = calculateProgressbarTimestamp(event);
    };
    $scope.clickOnProgressbar = function(event) {
      return $scope.seek(calculateProgressbarTimestamp(event));
    };
    $scope.changedSubtitle = function() {
      return tidalstreamService.playerSetSubtitle($scope.player.player_id, $scope.player.player.current_subtitle);
    };
    $scope.changedAudioStream = function() {
      return tidalstreamService.playerSetAudioStream($scope.player.player_id, $scope.player.player.current_audiostream);
    };
    interval = $interval((function() {}), 1000);
    $scope.$originalDestroy = $scope.$destroy;
    $scope.$destroy = function() {
      $interval.cancel(interval);
      return $scope.$originalDestroy();
    };
    calculateProgressbarTimestamp = function(event) {
      var clickWidth, width;
      width = event.currentTarget.offsetWidth;
      clickWidth = event.offsetX;
      return (clickWidth / width) * $scope.player.player.length;
    };
    return getSpeed = function(direction) {
      var currentSpeed, index, speeds;
      speeds = $scope.player.features.speed;
      currentSpeed = $scope.player.player.speed;
      if (__indexOf.call(speeds, 1) < 0) {
        speeds.push(1);
      }
      speeds.sort(function(a, b) {
        return a - b;
      });
      index = speeds.indexOf(currentSpeed);
      if (index === -1) {
        return null;
      }
      return speeds[index + direction] || currentSpeed;
    };
  });

  tidalstreamApp.controller('SearchBoxCtrl', function($scope, $location, tidalstreamService) {
    var currentUrl, section, templateMap;
    $scope.template = "assets/partials/search-loading.html";
    $scope.variables = {};
    $scope.schema = {};
    $scope.Math = window.Math;
    currentUrl = $location.search().url;
    section = currentUrl.split('/')[4];
    templateMap = {
      anime: 'mal',
      tvshows: 'imdb',
      movies: 'imdb'
    };
    tidalstreamService.getSearchSchema(section).then(function(data) {
      if (data.status === 'error' || !(data.type in templateMap)) {
        return $scope.template = 'assets/partials/search-nosearch.html';
      } else {
        $scope.schema = data.schema;
        return $scope.template = "assets/partials/search-" + templateMap[data.type] + ".html";
      }
    });
    $scope.doSearch = function() {
      var key, searchString, v, value, _i, _len, _ref;
      searchString = $scope.variables.q || '';
      console.log(searchString);
      _ref = $scope.variables;
      for (key in _ref) {
        value = _ref[key];
        if (key === 'q') {
          continue;
        }
        if (value instanceof Array) {
          for (_i = 0, _len = value.length; _i < _len; _i++) {
            v = value[_i];
            if (!v) {
              continue;
            }
            if (v.indexOf(' ') > -1) {
              v = "\"" + v + "\"";
            }
            searchString += " " + key + ":" + v;
          }
        } else {
          if (!value) {
            continue;
          }
          if (value.indexOf(' ') > -1) {
            value = "\"" + value + "\"";
          }
          searchString += " " + key + ":" + value;
        }
      }
      if (searchString) {
        $location.url($location.path());
        return $location.search('url', "" + tidalstreamService.featureList.search + "/" + section + "/?q=" + (encodeURIComponent(searchString)));
      }
    };
    $scope.toggleKey = function(type, key) {
      var index;
      if (!(type in $scope.variables)) {
        $scope.variables[type] = [];
      }
      index = $scope.variables[type].indexOf(key);
      if (index > -1) {
        return $scope.variables[type].splice(index, 1);
      } else {
        return $scope.variables[type].push(key);
      }
    };
    $scope.isYear = function(value) {
      return value.match(/^(19|20)\d{2}$/) !== null;
    };
    return $scope.not = function(func) {
      return function(item) {
        return !func(item);
      };
    };
  });

  tidalstreamApp.config(function($provide) {
    return $provide.factory('tidalstreamService', function($rootScope, $location, $http, $q, $log, $modal, $timeout) {
      var defaultPlayer, obj;
      obj = {
        apiserver: null,
        username: null,
        password: null,
        loggedIn: false,
        loadingData: true,
        featureList: {},
        sections: [],
        players: {},
        playbackOutput: {
          obj: null,
          status: 'offline',
          type: null
        },
        latestListing: null,
        latestListingUrl: null,
        searchSchemas: {},
        connectedToControl: false,
        onWebsocketUpdate: null,
        _metadataDB: null,
        _websocket: null,
        _connectStepBack: false,

        /*
        PLAYER RELATED STUFF
         */
        playerStop: function(playerId) {
          return obj._sendToWebsocket('stop', playerId);
        },
        playerNext: function(playerId) {
          return obj._sendToWebsocket('next', playerId);
        },
        playerPrevious: function(playerId) {
          return obj._sendToWebsocket('previous', playerId);
        },
        playerSetSpeed: function(playerId, speed) {
          obj.players[playerId].player.speed = speed;
          return obj._sendToWebsocket('set_speed', playerId, {
            speed: speed
          });
        },
        playerSeek: function(playerId, timestamp) {
          obj.players[playerId].player.current_time = timestamp;
          return obj._sendToWebsocket('seek', playerId, {
            time: timestamp
          });
        },
        playerPlayItem: function(playerId, href) {
          return obj._sendToWebsocket('open', playerId, {
            url: href
          });
        },
        playerSetAudioStream: function(playerId, trackId) {
          return obj._sendToWebsocket('set_audio_stream', playerId, {
            track_id: trackId
          });
        },
        playerSetSubtitle: function(playerId, trackId) {
          return obj._sendToWebsocket('set_subtitle', playerId, {
            track_id: trackId
          });
        },
        _websocketPing: function() {
          if (obj._websocket && obj.connectedToControl) {
            return obj._websocket.send(JSON.stringify({
              jsonrpc: "2.0",
              method: 'ping'
            }));
          }
        },
        _connectToWebSocket: function() {
          var prepareReconnect;
          prepareReconnect = function() {
            console.log('preparing', (obj._connectStepBack ? 10000 : 0));
            $timeout((function() {
              return obj._connectToWebSocket();
            }), (obj._connectStepBack ? 10000 : 0));
            return obj._connectStepBack = true;
          };
          return this._getToken().then((function(token) {
            var loginUrl, ws;
            loginUrl = "ws" + (obj.featureList.control.slice(4)) + "/manage/websocket?token=" + token;
            ws = obj._websocket = new WebSocket(loginUrl);
            ws.onopen = function() {
              obj._connectStepBack = false;
              return $rootScope.$apply(function() {
                return obj.connectedToControl = true;
              });
            };
            ws.onclose = function() {
              $rootScope.$apply(function() {
                return obj.connectedToControl = false;
              });
              return prepareReconnect();
            };
            ws.onerror = prepareReconnect;
            return ws.onmessage = obj._handleWebSocketMessage;
          }), prepareReconnect);
        },
        _disconnectToWebSocket: function() {
          return obj._websocket.close();
        },
        _updatePlayerTime: function() {
          var player, playerId, _ref, _results;
          _ref = obj.players;
          _results = [];
          for (playerId in _ref) {
            player = _ref[playerId];
            if ((player.player != null) && (player.player.length != null) && (player.player.current_time != null)) {
              _results.push(player.player.current_time += player.player.speed * UPDATE_PLAYER_INTERVAL / 1000);
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        },
        _getToken: function() {
          var deferred;
          deferred = $q.defer();
          $http.get("" + obj.featureList.tokenauth).success(function(data) {
            return deferred.resolve(data.token);
          }).error(function(data, status, headers, config) {
            return deferred.reject('failed to fetch url');
          });
          return deferred.promise;
        },
        _handleWebSocketMessage: function(e) {
          var data, defaultPlayer, key, player_id, value, _ref;
          data = JSON.parse(e.data);
          player_id = data.params.player_id;
          switch (data.method) {
            case 'hello':
              obj.players[player_id] = data.params;
              defaultPlayer = obj.getDefaultPlayer();
              if (obj.playbackOutput.type === 'player' && obj.playbackOutput.obj.player_id === player_id || defaultPlayer && defaultPlayer.type === 'player' && defaultPlayer.playerId === player_id) {
                obj.playbackOutput.obj = obj.players[player_id];
                obj.playbackOutput.status = 'online';
                obj.playbackOutput.type = 'player';
              }
              break;
            case 'update':
              _ref = data.params.player;
              for (key in _ref) {
                value = _ref[key];
                obj.players[player_id].player[key] = value;
              }
              break;
            case 'ended':
              obj.players[player_id].player = {};
              break;
            case 'bye':
              delete obj.players[player_id];
              if (obj.playbackOutput.obj.player_id === player_id) {
                obj.playbackOutput.status = 'offline';
              }
          }
          if (obj.onWebsocketUpdate instanceof Function) {
            return obj.onWebsocketUpdate();
          }
        },
        _sendToWebsocket: function(method, playerId, params) {
          var cmd;
          $log.debug('Sending message to websocket', method, playerId, params);
          if (playerId === null) {
            return;
          }
          cmd = {
            jsonrpc: "2.0",
            method: 'command',
            params: params || {}
          };
          cmd.params.player_id = playerId;
          cmd.params.method = method;
          return obj._websocket.send(JSON.stringify(cmd));
        },

        /*
        METADATA RELATED STUFF
         */
        _openMetadataDB: function() {
          var req;
          req = indexedDB.open(DB_NAME, DB_VERSION);
          req.onsuccess = function(evt) {
            return obj._metadataDB = this.result;
          };
          return req.onupgradeneeded = function(evt) {
            var store;
            return store = evt.currentTarget.result.createObjectStore(DB_STORE_NAME, {
              keyPath: 'href'
            });
          };
        },
        _getObjectStore: function(mode) {
          var tx;
          tx = this._metadataDB.transaction(DB_STORE_NAME, mode);
          return tx.objectStore(DB_STORE_NAME);
        },
        downloadMetadata: function(hrefs) {
          var href, _i, _len, _results;
          _results = [];
          for (_i = 0, _len = hrefs.length; _i < _len; _i++) {
            href = hrefs[_i];
            _results.push($http.get(href).success(function(data) {
              var item, store, _j, _len1, _results1;
              store = obj._getObjectStore('readwrite');
              if (data instanceof Array) {
                _results1 = [];
                for (_j = 0, _len1 = data.length; _j < _len1; _j++) {
                  item = data[_j];
                  _results1.push(store.put(item));
                }
                return _results1;
              } else if ('title' in data) {
                return store.put(data);
              }
            }));
          }
          return _results;
        },
        verifyMetadata: function(data) {
          var i, item, missingMetadata, store, verifyMetadataResult, _i, _len, _ref, _results;
          i = 0;
          store = this._getObjectStore('readonly');
          missingMetadata = {};
          verifyMetadataResult = function(href, data) {
            var category, hrefs, _results;
            i--;
            category = href.split('/').slice(0, -1).join('/');
            if (data === void 0) {
              if (!missingMetadata.hasOwnProperty(category)) {
                missingMetadata[category] = [];
              }
              missingMetadata[category].push(href);
            }
            if (i === 0) {
              _results = [];
              for (category in missingMetadata) {
                hrefs = missingMetadata[category];
                if (hrefs.length > 50) {
                  _results.push(obj.downloadMetadata([category]));
                } else {
                  _results.push(obj.downloadMetadata(hrefs));
                }
              }
              return _results;
            }
          };
          _ref = data.result;
          _results = [];
          for (_i = 0, _len = _ref.length; _i < _len; _i++) {
            item = _ref[_i];
            if ('metadata' in item) {
              i++;
              _results.push(store.get(item.metadata.href).onsuccess = (function(item) {
                return function(evt) {
                  return verifyMetadataResult(item.metadata.href, evt.target.result);
                };
              })(item));
            } else {
              _results.push(void 0);
            }
          }
          return _results;
        },

        /*
        MISC
         */
        detectFeatures: function() {
          var modalData, modalInstance, modalTimeout;
          $log.debug('Detecting features');
          modalInstance = null;
          modalData = {
            countdown: 30,
            errorMessage: null
          };
          modalTimeout = $timeout((function() {
            return modalInstance = $modal.open({
              templateUrl: 'assets/partials/logging-in.html',
              backdrop: 'static',
              controller: 'LoggingInCtrl',
              resolve: {
                data: function() {
                  return modalData;
                }
              }
            });
          }), 600);
          return $http.get(this.apiserver).success(function(data) {
            var info, name, _ref;
            if (modalTimeout) {
              $timeout.cancel(modalTimeout);
            }
            for (name in data) {
              info = data[name];
              if (info.rel === 'feature') {
                obj.featureList[name] = info.href;
              } else if (name === 'motd') {
                console.log('The MOTD:', info);
              }
            }
            _ref = obj.featureList;
            for (name in _ref) {
              info = _ref[name];
              $rootScope.$emit("feature-" + name);
            }
            if (modalInstance) {
              return modalInstance.dismiss();
            }
          }).error(function(data, status, headers, config) {
            return modalData.errorMessage = ['Failed to get features from APIServer. This means it is probably down!', 'You should try again later or contact your local system adminstrator'];
          });
        },
        hasLoggedIn: function(apiserver, username, password) {
          this.apiserver = apiserver;
          this.username = username;
          this.password = password;
          this.loggedIn = true;
          return this.detectFeatures();
        },
        hasLoggedOut: function() {
          this.loggedIn = false;
          this.apiserver = null;
          this.username = null;
          return this.password = null;
        },
        listFolder: function(path) {
          var deferred;
          if (path.indexOf('http') !== 0) {
            path = "" + this.apiserver + path;
          }
          deferred = $q.defer();
          if (path === this.latestListingUrl) {
            deferred.resolve(this.latestListing);
          } else {
            obj.loadingData = true;
            $http.get(path).success(function(data) {
              obj.loadingData = false;
              obj.latestListing = data;
              obj.latestListingUrl = path;
              deferred.resolve(data);
              if (Modernizr.indexeddb) {
                return obj.verifyMetadata(data);
              }
            }).error(function() {
              return obj.loadingData = false;
            });
          }
          return deferred.promise;
        },
        getMetadata: function(item) {
          var deferred, href;
          href = item.metadata.href;
          if (href.indexOf('http') !== 0) {
            href = "" + this.apiserver + path;
          }
          deferred = $q.defer();
          $http.get(href).success(function(data) {
            return deferred.resolve(data);
          });
          return deferred.promise;
        },
        populateNavbar: function() {
          return this.listFolder('/section').then(function(data) {
            return obj.sections = data.result;
          });
        },
        getSearchSchema: function(section) {
          var deferred;
          deferred = $q.defer();
          if (section in obj.searchSchemas) {
            deferred.resolve(obj.searchSchemas[section]);
          } else {
            $http.get("" + obj.featureList.search + "/" + section + "/?schema=1").success(function(data) {
              obj.searchSchemas[section] = data;
              return deferred.resolve(data);
            });
          }
          return deferred.promise;
        },
        doItemPlayback: function(item) {
          if (obj.playbackOutput.status !== 'online') {
            $rootScope.$emit('alert', 'warning', 'No player chosen, please choose a player before streaming.');
            return;
          }
          obj.loadingData = true;
          return $http.post(item.href).success(function(data) {
            if (data.status === 'error') {
              return console.log('show error msg on creating stream');
            } else {
              obj.loadingData = false;
              if (obj.playbackOutput.type === 'download') {
                return obj.openDownloadModal(data);
              } else if (obj.playbackOutput.type === 'player') {
                return obj.playerPlayItem(obj.playbackOutput.obj.player_id, data.href);
              }
            }
          });
        },
        openDownloadModal: function(item) {
          var modalInstance;
          return modalInstance = $modal.open({
            templateUrl: 'assets/partials/download.html',
            controller: 'DownloadCtrl',
            resolve: {
              item: function() {
                return item;
              }
            }
          });
        },
        getDefaultPlayer: function() {
          return JSON.parse(localStorage.getItem("defaultPlayer"));
        }
      };
      if (Modernizr.indexeddb) {
        obj._openMetadataDB();
      }
      $rootScope.$watch((function() {
        return $location.path();
      }), function(newValue, oldValue) {
        var apiserver, password, username;
        if (!(obj.loggedIn || newValue === '/login')) {
          if (!!(localStorage.getItem("autoLogin"))) {
            apiserver = localStorage.getItem("apiserver");
            username = localStorage.getItem("username");
            password = localStorage.getItem("password");
            return obj.hasLoggedIn(apiserver.replace(/\/+$/, ''), username, password);
          } else {
            return $location.path('/login');
          }
        }
      });
      $rootScope.$on('feature-section', function() {
        return obj.populateNavbar();
      });
      $rootScope.$on('feature-control', function() {
        return obj._connectToWebSocket();
      });
      setInterval(obj._updatePlayerTime, UPDATE_PLAYER_INTERVAL);
      setInterval(obj._websocketPing, WEBSOCKET_PING);
      defaultPlayer = obj.getDefaultPlayer();
      if (defaultPlayer && defaultPlayer.type === 'download') {
        obj.playbackOutput = {
          obj: null,
          status: 'online',
          type: 'download'
        };
      }
      return obj;
    });
  });

  tidalstreamApp.filter('timespan', function() {
    return function(input) {
      var hours, minutes, retval, seconds;
      input = parseInt(input, 10);
      hours = Math.floor(input / 3600);
      minutes = Math.floor(input % 3600 / 60);
      seconds = input % 60;
      minutes = minutes < 10 ? '0' + minutes : minutes;
      seconds = seconds < 10 ? '0' + seconds : seconds;
      retval = "" + minutes + ":" + seconds;
      if (hours > 0) {
        hours = hours < 10 ? '0' + hours : hours;
        retval = "" + hours + ":" + retval;
      }
      return retval;
    };
  });

}).call(this);