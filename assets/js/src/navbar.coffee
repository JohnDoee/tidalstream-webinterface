tidalstreamApp.controller 'NavbarCtrl', ($scope, $location, $modal, tidalstreamService) ->
    $scope.isLoggedIn = -> tidalstreamService.loggedIn
    $scope.getSections = -> tidalstreamService.sections
    $scope.getPlayers = -> tidalstreamService.players
    $scope.playbackOutput = tidalstreamService.playbackOutput
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
    
    savePlaybackOutput = (type, target) ->
        if localStorage.getItem "apiserver"
            currentPlayer =
                type: type
            
            if type == 'player'
                currentPlayer.playerId = target.player_id
            
            localStorage.setItem "defaultPlayer", JSON.stringify currentPlayer
    
    $scope.setPlaybackOutput = ($event, type, target) ->
        tidalstreamService.playbackOutput.obj = target
        tidalstreamService.playbackOutput.type = type
        tidalstreamService.playbackOutput.status = 'online'
        
        savePlaybackOutput type, target
        
        $event.stopPropagation()
        $event.preventDefault()
    
    tidalstreamService.onWebsocketUpdate = ->
        $scope.$digest()