$(document).ready(function () {
    $('.handlebar-partial').each(function () {
        Handlebars.registerPartial($(this).data('partial'), $(this).html());
    });
    
    var login_info = {
        'apiserver': '',
        'username': '',
        'password': '',
    }
    
    var last_url = '';
    var last_local_part = undefined;
    var cached_page;
    var cached_page_config = {};
    per_page = 60;
    pagination_cutoff = 5;
    
    var update_ajax_config = function(obj) {
        obj.dataType = 'json';
        obj.beforeSend = function(xhr) {
            xhr.setRequestHeader("Authorization", "Basic " + $.base64.encode(login_info.username + ":" + login_info.password));
            xhr.withCredentials = true;
        };
        return obj;
    };
    
    var download = function(url) {
        return $.ajax(update_ajax_config({url: url}));
    }
    
    var download_and_paginate = function(url, template, target) {
        download(url).done(function (data) {
            cached_page = data;
            cached_page_config = {
                'template': template,
                'target': target,
                'page_max': Math.floor(data['result'].length / per_page)
            };
            switch_to_page(0);
            update_page();
        });
    };
    
    var make_pagination_footer = function () {
        if (cached_page_config['page_max'] == 0) {
           $('#target_footer').html('');
           return;
        };
        
        var obj = [];
        var current_page = cached_page_config['page'];
        
        obj.push({
            'text': 'First',
            'target': 0,
            'cls': ''
        });
        
        obj.push({
            'text': 'Prev',
            'target': current_page-1,
            'cls': (current_page == 0) ? 'disabled' : ''
        });
        
        if (current_page - pagination_cutoff > 0) {
            obj.push({
                'text': '&hellip;',
                'target': 0,
                'cls': 'disabled'
            });
        };
        
        for (var i=Math.max(0, current_page - pagination_cutoff); i <= Math.min(cached_page_config['page_max'], current_page+pagination_cutoff); i++) {
            obj.push({
                'text': i+1,
                'target': i,
                'cls': (current_page == i) ? 'active' : ''
            })
        };
        
        if (current_page + 10 < cached_page_config['page_max']) {
            obj.push({
                'text': '&hellip;',
                'target': 0,
                'cls': 'disabled'
            });
        };
        
        obj.push({
            'text': 'Next',
            'target': current_page+1,
            'cls': (current_page == cached_page_config['page_max']) ? 'disabled' : ''
        });
        
        obj.push({
            'text': 'Last',
            'target': cached_page_config['page_max'],
            'cls': ''
        });
        
        render_to_target(obj, '.pagination-footer', '#target_footer');
    }
    
    var switch_to_page = function(page_num) {
        cached_page_config['page'] = page_num;
        cached_page['_page_num'] = page_num;
            
        render_to_target(cached_page, cached_page_config['template'], cached_page_config['target']);
        make_pagination_footer();
        update_metadata();
    };
    
    var update_metadata = function() {
        $('.metadatable').each(function () {
            var handle_metadata = function (metadata) {
                $(this).find('.metadata').each(function () {
                    var attrib = $(this).data('metadata');
                    var target = $(this).data('metadata-target');
                    if (metadata[attrib]) {
                        if (target == 'text') {
                            $(this).text(metadata[attrib])
                        } else {
                            $(this).attr(target, metadata[attrib])
                        };
                    };
                });
            };
            
            $.ajax(update_ajax_config({
                url: $(this).data('metadata-rel'),
                context: this,
            })).done(handle_metadata);
        });
    };
    
    var render_to_target = function(data, template, target) {
        if (data.content_type && $(template + '.' + data.content_type).length) {
            template = template + '.' + data.content_type;
        }
        template = Handlebars.compile($(template).html());
        $(target).html(template(data));
        $('html, body').scrollTop(0);
    };
    
    var download_and_render_to_target = function (url, template, target) {
        download(url).done(function (data) {
            render_to_target(data, template, target);
        });
    }
    
    $(document).on('submit', '#login', function(e) {
        e.preventDefault();
        login_info = {
            'apiserver': $('#apiserver').val().replace(/\/+$/,'') + '/section',
            'username': $('#username').val(),
            'password': $('#password').val()
        }
        
        download_and_render_to_target(login_info.apiserver, '.section-bar-template', '#section_bar');
        $('#target').html('Logging in, check bar above for Sections');
        window.location.hash = '#';
    });
    
    $(document).on('click', 'a.folder', function(e) {
        e.preventDefault();
        window.location.hash = '#!' + $(this).prop('href');
    });
    
    $(document).on('click', 'a.file', function(e) {
        e.preventDefault();
        $.ajax(update_ajax_config({
            url: $(this).prop('href'),
            method: 'POST'
        })).done(function (data) {
            location.href = data.href;
            //alert('Open url in any media player: ' + data.href);
        });
    });
    
    $(document).on('click', 'a.switch_page', function(e) {
        e.preventDefault();
        if (!$(this).parent().hasClass('disabled') && !$(this).parent().hasClass('active')) {
            switch_to_page($(this).data('target-page'));
        }
    });
    
    $(document).on('click', 'a.set_url_param', function(e) {
        e.preventDefault();
        
        var current_url = window.location.hash.split('?');
        if (current_url.length > 1) {
            var current_params = $.url('?' + current_url[1]).param();
        } else {
            var current_params = {};
        };
        
        current_params[$(this).data('param-name')] = $(this).data('param-value');
        
        window.location.hash = current_url[0] + '?' + $.param(current_params);
    });
    
    
    var create_login_form = function() {
        if (window.location.hash.indexOf('#!') == 0) {
            var hash_stuff = []
        } else {
            var hash_stuff = window.location.hash.slice(1).split('!');
        }
        
        var template = Handlebars.compile($(".login-form-template").html());
        $('#target').html(template({
            'apiserver': hash_stuff[0],
            'username': hash_stuff[1],
            'password': hash_stuff[2]
        }));
    };
    
    var update_page = function() {
        if (window.location.hash.indexOf('#!') != 0) {
            return;
        }
        
        var current_url = window.location.hash.substring(2).split('?');
        var local_part = current_url[1];
        current_url = current_url[0];
        
        if (login_info.apiserver) {
            if (current_url != last_url) {
                last_url = current_url;
                last_local_part = undefined;
                $.blockUI({ message: '<img src="/assets/img/spinner.gif" /> Loading....' }); 
                download_and_paginate(current_url, '.folder-listing-template', '#target');
            } else if (local_part != last_local_part) {
                var tmp = $.url('?' + last_local_part).param();
                last_local_part = local_part;
                local_part = $.url('?' + local_part).param();
                
                if (local_part['page'] != tmp['page']) {
                    var page_num = (local_part.hasOwnProperty('page')) ? local_part['page'] : 0;
                    switch_to_page(parseInt(page_num));
                }
            };
        }
    };
    
    $(window).on('hashchange', update_page);
    
    create_login_form();
    $(document).ajaxStop($.unblockUI); 
});

Handlebars.registerHelper('eachnum', function(context, options) {
    var ret = "";
    var count = parseInt(options.hash.count);
    var page = parseInt(options.hash.page);
    var sliced_context = context.slice(page*per_page, (page+1)*per_page);
    
    for(var i=0, j=sliced_context.length; i<j; i=i+count) {
      ret = ret + options.fn(sliced_context.slice(i,i+count));
    }
  
    return ret;
});
