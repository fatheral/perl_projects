-- phpMyAdmin SQL Dump
-- version 2.11.1.1
-- http://www.phpmyadmin.net
--
-- ����: localhost
-- ����� ��������: ��� 06 2008 �., 14:50
-- ������ �������: 5.0.45
-- ������ PHP: 5.2.4

SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

--
-- ���� ������: 'search'
--

-- --------------------------------------------------------

--
-- ��������� ������� 'ftpcount'
--

CREATE TABLE IF NOT EXISTS ftpcount (
  ftp_count bigint(20) unsigned NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='������� ������� ���������';

-- --------------------------------------------------------

--
-- ��������� ������� 'ftpcumreq'
--

CREATE TABLE IF NOT EXISTS ftpcumreq (
  ftp_cum_req_id mediumint(8) unsigned NOT NULL auto_increment COMMENT '��������� ����',
  ftp_req text NOT NULL COMMENT '������',
  ftp_req_cnt mediumint(8) unsigned NOT NULL COMMENT '���������� ����� ��������',
  PRIMARY KEY  (ftp_cum_req_id)
) ENGINE=MyISAM  DEFAULT CHARSET=utf8 COMMENT='�������, ���������� ������� � �� ����������';

-- --------------------------------------------------------

--
-- ��������� ������� 'ftpreq'
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
-- ��������� ������� 'ftpsearch'
--

CREATE TABLE IF NOT EXISTS ftpsearch (
  ftp_file_id mediumint(8) unsigned NOT NULL COMMENT 'id ������ �� �������',
  ftp_parent_id mediumint(8) unsigned default NULL COMMENT 'id ������������� ��������',
  ftp_dir text NOT NULL COMMENT '������������ ����������',
  ftp_name text COMMENT '��� �������� ����� ��� ����������',
  ftp_isdir char(1) NOT NULL default 'd' COMMENT '���������� ��� ����',
  ftp_size bigint(15) unsigned NOT NULL default '0' COMMENT '������',
  ftp_server_id tinyint(3) unsigned NOT NULL COMMENT 'id ���-�������',
  ftp_indtime datetime NOT NULL COMMENT '����� ����������',
  PRIMARY KEY  (ftp_file_id,ftp_server_id),
  KEY ftp_parent_id (ftp_parent_id,ftp_server_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8;

-- --------------------------------------------------------

--
-- ��������� ������� 'ftpserver'
--

CREATE TABLE IF NOT EXISTS ftpserver (
  ftp_server_id tinyint(3) unsigned NOT NULL COMMENT 'id ���-�������',
  ftp_server varchar(255) NOT NULL COMMENT '��� ���-�������',
  PRIMARY KEY  (ftp_server_id)
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='������� ���-��������';
