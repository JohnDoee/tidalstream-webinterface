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