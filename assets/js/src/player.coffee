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