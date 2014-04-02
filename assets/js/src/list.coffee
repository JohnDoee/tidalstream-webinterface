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