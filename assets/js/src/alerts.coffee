tidalstreamApp.controller 'AlertCtrl', ($scope, $rootScope, tidalstreamService) ->
    $scope.data =
        alerts: []
    
    $scope.closeAlert = (index) ->
        $scope.data.alerts.splice index, 1
    
    $rootScope.$on 'alert', ($event, type, msg) ->
        $scope.data.alerts.push
            type: type
            msg: msg