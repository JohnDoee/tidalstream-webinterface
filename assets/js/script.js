$(document).ready(function () {
    var login_info = {
        'apiserver': '',
        'username': '',
        'password': '',
    }
    
    var request_url = function(url, method) {
        if (!method) {
            method = 'GET';
        }
        
        return $.ajax({
            url: url,
            method: method,
            dataType: 'json',
            beforeSend: function(xhr) {
                xhr.setRequestHeader("Authorization", "Basic " + $.base64.encode(login_info.username + ":" + login_info.password));
                xhr.withCredentials = true;
            }
        });
    };
    
    var render_to_target = function(url, template, target) {
        request_url(url).done(function (data) {
            template = Handlebars.compile($(template).html());
            $(target).html(template(data));
        });
    };
    
    $(document).on('submit', '#login', function(e) {
        e.preventDefault();
        login_info = {
            'apiserver': $('#apiserver').val(),
            'username': $('#username').val(),
            'password': $('#password').val()
        }
        
        render_to_target(login_info.apiserver, '#section-bar-template', '#section_bar');
        $('#target').html('Logging in, check bar above for Sections');
        window.location.hash = '#!' + login_info.apiserver;
    });
    
    // 
    $(document).on('click', 'a.folder', function(e) {
        e.preventDefault();
        window.location.hash = '#!' + $(this).prop('href');
    });
    
    $(document).on('click', 'a.streamable', function(e) {
        e.preventDefault();
        request_url($(this).prop('href'), 'POST').done(function (data) {
            alert('Open url in any media player: ' + data.href);
        });
    });
    
    var create_login_form = function() {
        if (window.location.hash.indexOf('#!') == 0) {
            var hash_stuff = []
        } else {
            var hash_stuff = window.location.hash.slice(1).split('!');
        }
        
        var template = Handlebars.compile($("#login-form-template").html());
        $('#target').html(template({
            'apiserver': hash_stuff[0],
            'username': hash_stuff[1],
            'password': hash_stuff[2]
        }));
    };
    
    $(window).on('hashchange', function(e) {
        if (window.location.hash.indexOf('#!') != 0) {
            return;
        }
        
        if (login_info.apiserver) {
            render_to_target(window.location.hash.substring(2), '#folder-listing-template', '#target');
        }
    });
    
    create_login_form();
});