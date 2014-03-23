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