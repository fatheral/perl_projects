-- phpMyAdmin SQL Dump
-- version 2.11.1.1
-- http://www.phpmyadmin.net
--
-- Хост: localhost
-- Время создания: Авг 06 2008 г., 14:50
-- Версия сервера: 5.0.45
-- Версия PHP: 5.2.4

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

--
-- База данных: 'search'
--

-- --------------------------------------------------------

--
-- Структура таблицы 'ftpcount'
--

CREATE TABLE IF NOT EXISTS ftpcount (
  ftp_count bigint(20) unsigned NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Простой счетчик посещений';

-- --------------------------------------------------------

--
-- Структура таблицы 'ftpcumreq'
--

CREATE TABLE IF NOT EXISTS ftpcumreq (
  ftp_cum_req_id mediumint(8) unsigned NOT NULL auto_increment COMMENT 'Первичный ключ',
  ftp_req text NOT NULL COMMENT 'Запрос',
  ftp_req_cnt mediumint(8) unsigned NOT NULL COMMENT 'Количество таких запросов',
  PRIMARY KEY  (ftp_cum_req_id)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='Таблица, содержащая запросы и их количество';

-- --------------------------------------------------------

--
-- Структура таблицы 'ftpreq'
--

CREATE TABLE IF NOT EXISTS ftpreq (
  ftp_req_id int(10) unsigned NOT NULL auto_increment,
  ftp_req_ip char(15) NOT NULL,
  ftp_req varchar(255) NOT NULL,
  ftp_req_time datetime NOT NULL,
  PRIMARY KEY  (ftp_req_id)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы 'ftpsearch'
--

CREATE TABLE IF NOT EXISTS ftpsearch (
  ftp_file_id mediumint(8) unsigned NOT NULL COMMENT 'id записи на сервере',
  ftp_parent_id mediumint(8) unsigned default NULL COMMENT 'id родительского каталога',
  ftp_dir text NOT NULL COMMENT 'Родительская директория',
  ftp_name text COMMENT 'Имя текущего файла или директории',
  ftp_isdir char(1) NOT NULL default 'd' COMMENT 'Директория или файл',
  ftp_size bigint(15) unsigned NOT NULL default '0' COMMENT 'Размер',
  ftp_server_id tinyint(3) unsigned NOT NULL COMMENT 'id фтп-сервера',
  ftp_indtime datetime NOT NULL COMMENT 'Время индексации',
  PRIMARY KEY  (ftp_file_id,ftp_server_id),
  KEY ftp_parent_id (ftp_parent_id,ftp_server_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- Структура таблицы 'ftpserver'
--

CREATE TABLE IF NOT EXISTS ftpserver (
  ftp_server_id tinyint(3) unsigned NOT NULL COMMENT 'id фтп-сервера',
  ftp_server varchar(255) NOT NULL COMMENT 'имя фтп-сервера',
  PRIMARY KEY  (ftp_server_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Таблица фтп-серверов';
