our %cfg = (

	'db' => {
		'host'		=> 'localhost',
		'dbname'	=> 'search',
		'login'		=> 'search',
		'pass'		=> '******',
	},

	'servers' => {
		'ftp' => {
			'id'		=> 1,
			'included_dirs'	=> [ '/' ],
			'excluded_dirs'	=> [ '/exchange' ],
#			'excluded_dirs' => [ ],
		},
		'newftp' => {
			'id'		=> 2,
			'included_dirs'	=> [ '/' ],
			'excluded_dirs'	=> [ ],
		},
		'artem' => {
			'id'		=> 4,
			'included_dirs'	=> [ '/' ],
			'excluded_dirs' => [ '/artem', '/upload' ],
		},
		'lost'	=> {
			'id'		=> 3,
			'included_dirs'	=> [ '/' ],
			'excluded_dirs'	=> [ ],
		},
	},

	'charset_ftp'	=> 'cp1251',
	'charset_db'	=> 'utf8',
	'charset_web'	=> 'koi8r',

	'ind_log'	=> '/usr/home/www/search/ftpindex.log',
	'search_log'	=> '/usr/home/www/search/ftpsearch.log',

	'picture_path'	=> '/usr/home/www/search/www/',
	'picture_file'	=> 'daily_fstat.png',
);

1;
