our %cfg = (

	'db'		=> {
		'dbname'	=> 'ftpsearch',
		'host'		=> '192.168.10.115',
		'login'		=> 'ftp',
		'pass'		=> '******',
	},

	'id'		=> 1,

	'dirs'		=> {
		'incl_dir'	=> [
			'/ftp',
		],
		'excl_dir'	=> [
			'/ftp/incoming/TEMP_3_days',
		],
	},

	'log'           => '/home/anchorite/ftpsearch/ftpindex.log',
);
