function autosuggest()
{
	var url = 'http://search.bks-tv.ru/cgi/ajax.pl';
	if ($.trim($('#q').val()) != '') {
		$.get(url, { q: $.trim($('#q').val()) }, function(html) { $('#suggestions').html(html); });
	}
	else {
		$('#suggestions').html('');
	}
}

function setq(v)
{
        $('#q').val(v);
        $('#suggestions').html('');
}

function setVisible()
{
	if ($('#addition').css('visibility') == 'hidden') {
		$('#addition').css({visibility: 'visible'});
	}
	else {
		$('#addition').css({visibility: 'hidden'});
	}
}

$(document).ready(function() { $('#q').focus(); });
