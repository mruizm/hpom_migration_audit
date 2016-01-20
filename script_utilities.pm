#!/usr/local/bin/perl
package script_utilities;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT = qw/ logger check_at_least_one_option /;

######################################################################
# Sub to write errors, warnings, or information within a local file
#	@Parms:
#		$log_object 	: object which created the entry
#		$error_log		: path of file to which add log entry
#		$entry_Line		: Array as reference
#	Return:
#		none
######################################################################
sub logger{
	my $log_object = $_[0];
	my $error_log = $_[1];
	my $entryLine = $_[2];

	open (MYFILE, ">> $error_log");
    print MYFILE "$log_object: @$entryLine";
    close (MYFILE);
}

##########################################################
# Sub that checks if at least one options is used
#	@Parms:
#			%priv_hash_options:		Hash with options
#	Return:
#			0:	If no options used
#			1:	If at least one (1) options used#
###########################################################
sub check_at_least_one_option
{
	my %priv_hash_options = %{$_[0]};
	my $one_options_at_least = "0";
	foreach my $options_hash_values (values %priv_hash_options)
	{
		if ($options_hash_values eq "1")
		{
			$one_options_at_least = "1";
		}
	}
	if ($one_options_at_least eq "0")
	{
		return 1;
	}
	else
	{
		return 0;
	}
}
1;
