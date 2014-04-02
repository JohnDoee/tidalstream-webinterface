tidalstreamApp.controller 'FrontCtrl', ($scope, tidalstreamService) ->
    $scope.features = tidalstreamService.featureList