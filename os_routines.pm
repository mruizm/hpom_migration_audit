#!/usr/local/bin/perl
package os_routines;
use strict;
use warnings;

######################################################################
# Sub that renames a file within a managed node
#	@Parms:
#		$filename_path_one 		: path to source file
#		$nodename 				: Nodename
#		$node_os 				: win|ux
#		$source_filename		: source filename
#		$destination_filename	: destination filename
#	Return:
#		0				: File renamed sucessfully
#		1 				: File NOT renamed sucessfully
######################################################################
sub check_remote_file
{
	my $nodename = $_[0];
	my $node_os = $_[1];
	my $file_name_path = $_[2];
	my $file_name = $_[3];
	my @check_file_cmd = '';
	my $return_code = "0";
	chomp($file_name);

	if ($node_os eq "win")
	{
		#print "ovdeploy -cmd \'dir \"$file_name_path$file_name\"\' -node $nodename | grep \"$file_name\" | awk \'\{print \$5\}";
		@check_file_cmd = qx{ovdeploy -cmd \'dir \"$file_name_path$file_name\"\' -node $nodename | grep \"$file_name\" | awk \'\{print \$5\}};
	}
	if ($node_os eq "ux")
	{
		@check_file_cmd = qx{ovdeploy -cmd \"ls -l $file_name_path\" -node $nodename | grep \"$file_name\" | awk \'\{print \$9\}};
	}
	foreach my $check_file_line (@check_file_cmd)
	{
		chomp ($check_file_line);
		if ($check_file_line =~ m/^$file_name$/)
		{
			return 0;
		}
		else
		{
			logger("check_remote_file\(\): ".$nodename, $LOG_PATH."/".$FILENAME.".log", \@check_file_cmd);
			return 1;
		}
	}
}


######################################################################
# Sub that renames a file within a managed node
#	@Parms:
#		$filename_path_one 		: path to source file
#		$nodename 				: Nodename
#		$node_os 				: win|ux
#		$source_filename		: source filename
#		$destination_filename	: destination filename
#	Return:
#		0				: File renamed sucessfully
#		1 				: File NOT renamed sucessfully
######################################################################
sub rename_file_routine
{
	my $filename_path_one = $_[0];
	chomp($filename_path_one);
	my $return_code = "0";
	my $nodename = $_[1];
	my $node_os = $_[2];
	my $source_filename = $_[3];
	my $destination_filename = $_[4];

	my @rename_cmd = '0';

	if ($node_os eq "win")
	{
		@rename_cmd = qx{ovdeploy -cmd \'rename \"$filename_path_one$source_filename" \"$destination_filename\"\' -node $nodename};
	}
	if ($node_os eq "ux")
	{
		#print "mv $filename_path_one$source_filename $filename_path_one$destination_filename";
		@rename_cmd = qx{ovdeploy -cmd \"mv $filename_path_one$source_filename $filename_path_one$destination_filename\" -node $nodename};
	}

	if ($? eq "0")
	{
		return 0;
	}
	else
	{
		logger("rename_file_routine\(\): ".$nodename, $LOG_PATH."/".$FILENAME.".log", \@rename_cmd);
		return 1;
	}
}

######################################################################
# Sub that uploads db_mon.cfg file within a managed node
#	@Parms:
#		$mon_filename 	: file to upload
#		$mon_file_sd	: file's source directory within HPOM filesystem
#		$mon_file_td	: file's target directory within node filesystem
#		$nodename 		: Nodename
#	Return:
#		0				: If file uploaded sucessfully
#		1 				: If file NOT uploaded sucessfully
######################################################################
sub upload_mon_test_file
{
	my $mon_filename = $_[0];
	my $mon_file_sd = $_[1];
	my $mon_file_td = $_[2];
	my $nodename = $_[3];
	my @upload_cmd = qx{ovdeploy -upload -file $mon_filename -sd $mon_file_sd -td \'$mon_file_td\' -node $nodename};
	#if ($upload_cmd =~ m/File successfully uploaded/)
	if ($? eq "0")
	{
		return 0;
	}
	else
	{
		logger("upload_mon_test_file\(\): ".$nodename, $LOG_PATH."/".$FILENAME.".log", \@upload_cmd);
		return 1;
	}
}
