#!/usr/local/bin/perl
package hpom_validation_routines;
use strict;
use warnings;
require 'script_utilities.pm';

use script_utilities qw ( logger );
use base 'Exporter';
our @EXPORT = qw/ check_node_in_HPOM testOvdeploy_HpomToNode_383 testOvdeploy_HpomToNode_SSL testOvdeploy_NodeToHPOM_383  testOvdeploy_NodeToOVR_383 getNodeSysData /;
our $CURRENT_DATE = `date "+%m%d%Y_%H%M%S"`;
chomp($CURRENT_DATE);
our $LOG_PATH = `pwd`;
chomp($LOG_PATH);
our $FILENAME = "NOK_pre_migrate_audit";
our $LOG_BASE_PATH_FILE = $LOG_PATH."/".$FILENAME."_".$CURRENT_DATE.".log";

######################################################################
#			Miscellaneous monitoring routines						 #
######################################################################

######################################################################
#
# Library that contains miscellaneous validations for monitoring scripts
# Author: Marco Ruiz Mora (GETC - Systems Monitoring)
# Date: Oct, 7th 2015
# Version: 1.0
# Routines:
#	get_dbmon_metrics()				Sub that gets actual values of the metric defined to test
#	write_dbmon_cfg()				Sub that builds testing line using db_mon.cfg syntax
#	check_remote_file()				Sub that renames a file within a managed node
#	get_dbmon_instances()			Sub that gets db instances from dbmon configuration file within a managed node
#	rename_file_routine() 			Sub that renames a file within a managed node
#	upload_mon_test_file() 			Sub that uploads db_mon.cfg file within a managed node
#	generate_initial_dbmon_file() 	Sub that create db_mon.cfg baseline file
# 	run_ww_dbmon() 	 				Sub that executes ww_dbmon within a managed node
# 	logger()						Sub to write errors, warnings, or information within a local file
# 	checkOsType()					Sub that gets the OS type and DB type (if any) of a managed node
#	check_node_in_HPOM()			Sub that checks if a managed node is within a HPOM and if managed
#	getOsTypeNode()					Sub that gets OS version from node's ovconfget
#
#	check_at_least_one_option()		Sub that checks that at least one option is used
#
######################################################################



######################################################################
# Sub that checks if a managed node is within a HPOM and if found determine if its managed get mach_type and ip address
#	@Parms:
#		$nodename : Nodename to check
#	Return:
#		$node_mach_type_ip_addr[0] = 1: If nodename is not found within HPOM
#		@node_mach_type_ip_addr = (node_mach_type, node_ip_address)	:
#															MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX|
#															MACH_BBC_WIN|MACH_BBC_OTHER_IP
######################################################################
sub check_node_in_HPOM
{
	my $nodename = $_[0];
	my $nodename_exists = "1";
	my @node_mach_type_ip_addr = ();
	my ($node_ip_address, $node_mach_type) = ("", "");
	my @opcnode_out = qx{opcnode -list_nodes node_list=$nodename};
	foreach my $opnode_line_out (@opcnode_out)
	{
		chomp($opnode_line_out);
		if ($opnode_line_out =~ /^Name/)
		{
			$nodename_exists = "0"					# change to 0 if node is found
		}
		if ($opnode_line_out =~ m/IP-Address/)
		{
			$opnode_line_out =~ m/.*=\s(.*)/;
			$node_ip_address = $1;
			chomp($node_ip_address);
			push (@node_mach_type_ip_addr, $node_ip_address);
		}
		if ($opnode_line_out =~ m/MACH_BBC_LX26|MACH_BBC_SOL|MACH_BBC_HPUX|MACH_BBC_AIX|MACH_BBC_WIN|MACH_BBC_OTHER_IP/)
		{
			$opnode_line_out =~ m/.*=\s(.*)/;
			$node_mach_type = $1;
			chomp($node_mach_type);
			push (@node_mach_type_ip_addr, $node_mach_type);
		}
	}
	# Nodename not found
	if ($nodename_exists eq "1")
	{
		$node_mach_type_ip_addr[0] = "1";
	}

return @node_mach_type_ip_addr;
}

######################################################################
# Sub that gets OS type from node's ovconfget
#	@Parms:
#		$nodename : Nodename to check
#	Return:
#		1 	 							: If subroutine can't get OS type
#		AIX|HP-UX|Linux|SunOS|Windows	: OS type
######################################################################
sub getOsTypeNode
{
	my $nodename = $_[0];
	my @ovconfpar_os_val = qx{ovconfpar -get -host $nodename -ns eaagt.sysdata | grep -i \'^ostype*\' | awk \'BEGIN {FS=\"=\"};{print \$2}\'};
	foreach my $ovconf_par_line (@ovconfpar_os_val)
	{
		chomp($ovconf_par_line);
		#print "$ovconf_par_line\n";
		if ($ovconf_par_line =~ m/AIX|HP-UX|Linux|SunOS|Windows/)
		{
			return $ovconf_par_line
		}
		if ($ovconf_par_line eq "")
		{
			@ovconfpar_os_val = qq{Can't retrieve OS value};
			logger("\n".$nodename.":"."getOsType\(\)", $LOG_PATH."/".$FILENAME.".log", \@ovconfpar_os_val);
			return 1;
		}
	}
}

##########################################################
# Sub that checks node's port 383 from HPOM
#	@Parms:
#			$nodename:		Nodename
#	Return:
#			0:	OK
#			1:	Timed out
#			2:	Unavailable
###########################################################
sub testOvdeploy_HpomToNode_383
{
	my $nodename = $_[0];
	my $HPOM_ip = `hostname`;
	chomp($HPOM_ip);
	my $cmdtimeout = $_[1];
	my $eServiceOK_found;
	my @final_remote_bbcutil_ping_node;
	my @remote_bbcutil_ping_node = qx{ovdeploy -cmd bbcutil -par \"-ping http://$nodename\" -host $HPOM_ip -cmd_timeout $cmdtimeout};
	my @remote_bbcutil_ping_node_edited = ();
	foreach my $bbcutil_line_out (@remote_bbcutil_ping_node)
	{
		chomp($bbcutil_line_out);
		if ($bbcutil_line_out =~ m/eServiceOK/)
		{
			$eServiceOK_found = "0";
		}
		if ($bbcutil_line_out =~ m/^ERROR:/)
		{
			$eServiceOK_found = "1";					# change to 1 if error while making test
		}
	}
	if ($eServiceOK_found eq "0")
	{
		return 0;
	}
	if ($eServiceOK_found eq "1")
	{
		foreach my $raw_error_line(@remote_bbcutil_ping_node)
		{
			chomp($raw_error_line);
			$raw_error_line =~ s/\s+/ /g;
			push(@remote_bbcutil_ping_node_edited, $raw_error_line);
		}
		logger("\n".$nodename.":"."testOvdeploy_HpomToNode_383\($HPOM_ip\)", $LOG_BASE_PATH_FILE, \@remote_bbcutil_ping_node_edited);
		return 1;
	}
}

##########################################################
# Sub that checks SSL to node's port 383 from HPOM
#	@Parms:
#			$nodename:		Nodename
#	Return:
#			0:	OK
#			1:	Timed out
#			2:	Unavailable
#			3:	SSL error
###########################################################
sub testOvdeploy_HpomToNode_SSL
{
	my $nodename = $_[0];
	my $HPOM_ip = `hostname`;
	chomp($HPOM_ip);
	my $cmdtimeout = $_[1];
	my $eServiceOK_found = "";
	my @remote_bbcutil_ping_node_ssl = qx{ovdeploy -cmd bbcutil -par \"-ping https://$nodename\" -host $HPOM_ip -cmd_timeout $cmdtimeout};
	my @remote_bbcutil_ping_node_ssl_edited = ();
	foreach my $bbcutil_line_out_ssl (@remote_bbcutil_ping_node_ssl)
	{
		chomp($bbcutil_line_out_ssl);
		if ($bbcutil_line_out_ssl =~ m/eServiceOK/)
		{
			$eServiceOK_found = "0";
		}
		if ($bbcutil_line_out_ssl =~ m/^ERROR:/)
		{
			$eServiceOK_found = "1";
		}
	}
	if ($eServiceOK_found eq "0")
	{
		return 0;
	}
	if ($eServiceOK_found eq "1")
	{
		foreach my $raw_error_line(@remote_bbcutil_ping_node_ssl)
		{
			chomp($raw_error_line);
			$raw_error_line =~ s/\s+/ /g;
			push(@remote_bbcutil_ping_node_ssl_edited, $raw_error_line);
		}
		logger("\n".$nodename.":"."testOvdeploy_HpomToNode_SSL\($HPOM_ip\)", $LOG_BASE_PATH_FILE, \@remote_bbcutil_ping_node_ssl_edited);
		return 1;
	}
}

######################################################################
# Sub that test port 383 by ovdeploy to a HPOM
#	@Parms:
#		$nodename : 		Nodename to check
#		$remoteHPOM_ip:		Remote HPOM ip
#		$cmdtimeout:		cmd timeout
#		$target_cmd_dir:	location of cmd
#	Return:
#		0:		Sucessful test
#		1:		Not sucessful test
######################################################################
sub testOvdeploy_NodeToHPOM_383
{
	my $nodename = $_[0];
	my $remoteHPOM_ip = $_[1];
	my $cmdtimeout = $_[2];
	my $eServiceOK_found = "";
	my @remote_bbcutil_ping = qx{ovdeploy -cmd bbcutil -par \"-ping http://$remoteHPOM_ip\" -host $nodename -cmd_timeout $cmdtimeout};
	my @remote_bbcutil_ping_edited = ();
	foreach my $bbcutil_line_out (@remote_bbcutil_ping)
	{
		chomp($bbcutil_line_out);
		if ($bbcutil_line_out =~ m/eServiceOK/)
		{
			$eServiceOK_found = "0";
		}
		if ($bbcutil_line_out =~ m/^ERROR:/)
		{
			$eServiceOK_found = "1";				# change to 1 if error while making test
		}
	}
	if ($eServiceOK_found eq "0")
	{
		return 0;
	}
	if ($eServiceOK_found eq "1")
	{
		foreach my $raw_error_line(@remote_bbcutil_ping)
		{
			chomp($raw_error_line);
			$raw_error_line =~ s/\s+/ /g;
			push(@remote_bbcutil_ping_edited, $raw_error_line);
		}
		logger("\n".$nodename.":"."testOvdeploy_NodeToHPOM_383\($remoteHPOM_ip\)", $LOG_BASE_PATH_FILE, \@remote_bbcutil_ping_edited);
		return 1;
	}
}
##########################################################
# Sub that checks communication to OVR server
#	@Parms:
#			$nodename:		Nodename
#	Return:
#			@results_ovcodautil_ovr:	Array with $OvBbcCb_test, $Coda_test
###########################################################
sub testOvdeploy_NodeToOVR_383
{
	my $nodename = $_[0];
	my $ovr_ip = $_[1];
	my $cmdtimeout = $_[2];
	my ($OvBbcCb_test, $Coda_test, $error_reported) = ("99", "99", "99");
	my @results_ovcodautil_ovr = ();
		my @ovcodautil_ovr = qx{ovdeploy -cmd ovcodautil -par \"-ping -n $ovr_ip\" -host $nodename -cmd_timeout $cmdtimeout};
	my @ovcodautil_ovr_edited = ();
	foreach my $ovcodautil_ovr (@ovcodautil_ovr)
	{
		chomp($ovcodautil_ovr);
		if ($ovcodautil_ovr =~ /Ping of \'OvBbcCb\' at:.*(successful)/)
		{
			$OvBbcCb_test = "0";
			$error_reported = "0";
		}
		if ($ovcodautil_ovr =~ /Ping of \'Coda\' at:.*(successful)/)
		{
			$Coda_test = "0";
			$error_reported = "0";
		}
		if ($ovcodautil_ovr =~ /Ping of.*(failed)/)
		{
			$error_reported = "99";
		}
	}
	if ($error_reported eq "99")
	{
		foreach my $raw_error_line(@ovcodautil_ovr)
		{
			chomp($raw_error_line);
			$raw_error_line =~ s/\s+/ /g;
			push(@ovcodautil_ovr_edited, $raw_error_line);
		}
		logger("\n".$nodename.":"."testOvdeploy_NodeToOVR_383\($ovr_ip\)", $LOG_BASE_PATH_FILE, \@ovcodautil_ovr_edited);
	}
	@results_ovcodautil_ovr = ($OvBbcCb_test, $Coda_test);
	return @results_ovcodautil_ovr;
}

##########################################################
# Sub that get os sysdata from node
#	@Parms:
#			$nodename:		Nodename
#	Return:
#			@os_sys_data:	Array with agtbits|cputype|osbits|osfamily|osname|ostype
###########################################################
sub getNodeSysData
{
	my $nodename = $_[0];
	my $namespace_value = "";
	my $return_complete_os_data = "";
	my @os_sys_data = ();
	my @ovconfpar_os_val = qx{ovconfpar -get -host $nodename -ns eaagt.sysdata};
	foreach my $ovconf_par_line (@ovconfpar_os_val)
	{
		chomp($ovconf_par_line);
		#print "$ovconf_par_line\n";
		if ($ovconf_par_line =~ m/agtbits|cputype|osbits|osfamily|osname|ostype/)
		{
			$namespace_value = $ovconf_par_line;
			$namespace_value =~ m/.*=(.*)/;
			$namespace_value = $1;
			if ($namespace_value eq "")
			{
				$namespace_value = "N/A";
			}
			push(@os_sys_data, $namespace_value);
		}
	}
	return @os_sys_data;
}
1;
