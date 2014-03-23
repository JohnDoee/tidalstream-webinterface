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