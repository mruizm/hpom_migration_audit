#!/usr/local/bin/perl

##########################################################
# Information displayed regardless selecyed option(s):
#	NodeFqdn
#	NodeInHpom
#	NodeIp
#	NodeMachType
#	383HpomToNode
#	SslHpomToNode
#	AgtBits
#	CpuType
#	OsBits
#	OsFamily
#	OsName
#	OsType
# -a				: check port 383 from node to defined HPOM (-M parm)
# -b				: check port 383 and coda from node to defined OVR (-R parm)
# -c				: check ICMP from node to defined HPOM (-M) and/or defined OVR (-R)
###########################################################
use warnings;
use strict;
require 'hpom_validation_routines.pm';
require 'script_utilities.pm';
require 'os_routines.pm';

use hpom_validation_routines qw (  check_node_in_HPOM testOvdeploy_HpomToNode_383 testOvdeploy_HpomToNode_SSL testOvdeploy_NodeToHPOM_383 testOvdeploy_NodeToOVR_383 getNodeSysData );
use script_utilities qw ( check_at_least_one_option logger );
use os_routines qw (icmp_to_host_test);
use Getopt::Std;

$Getopt::Std::STANDARD_HELP_VERSION = 1;
our $VERSION = '1.0';

my %options = ();
my $one_options_at_least = "0";
my ($nodename, $hpom_ip, $ovr_ip, $cmd_timeout, $csv_line);
my ($result_testOvdeploy_HpomToNode_383, $return_testOvdeploy_HpomToNode_SSL) = (99,99);
my $result_testOvdeploy_NodeToHPOM_383 = "";
my @return_getNodeSysData = ();
my @testOVRconnection = ();
my @all_HPOMs = ();
my ($a_out);
my $init_csv_header = "NodeFqdn;NodeInHpom;NodeIp;NodeMachType;383HpomToNode;SslHpomToNode;AgtBits;CpuType;OsBits;OsFamily;OsName;OsType";
my $numHpoms = 0;
my $numHpomsString = "";
my $numOvrString = "";
my $icmpHeader = "";
my $hpom_ip_option_c = "";
my $ovr_ip_option_c = "";
my $results_icmp_hpom = "";
my $results_icmp_ovr = "";
my $results_icmp_all = "";

getopts('abcM:R:L:T:', \%options);

if (!%options)
{
	print "No options selected. Use --help to see all options\n";
	exit 1;
}
else
{
	if (!$options{L})
	{
		print "Please define the file with list of servers to audit! Option -L <file_with_servers_list>\n";
		exit 1;
	}
	if (!$options{T})
	{
		$options{T} = "3000";
		print "Using default timeout: 3000ms\n";
	}
	if (check_at_least_one_option(\%options) == 1)
	{
		print "Please use at least one option! Use --help to see all options.\n";
		exit 1;
	}
	if ($options{M})
	{
		#Separates HPOMs defined within 'M' argument
		$hpom_ip = $options{M};
		chomp($hpom_ip);
		$hpom_ip_option_c = $hpom_ip;

		#Array with defined HPOMs
		@all_HPOMs = split(' ', $hpom_ip);
					# count number of HPOMs defined in -M parameter
		$numHpoms = 1 + ($hpom_ip =~ tr{ }{ });

		#Strings that holds string when node is not found in HPOM, HPOM can't connect to port 383 and/or HPOM has no ssl connection to node
		for (my $i=0; $i < $numHpoms; $i++)
		{
			$numHpomsString = ";"."NA".$numHpomsString;
		}
	}
	if ($options{R})
	{
		$ovr_ip = $options{R};
		chomp($ovr_ip);
		$ovr_ip_option_c = $ovr_ip;
	}
		my $nodesFileList = $options{L};
		#Adds defined HPOMs to csv header
		if (($options{a}) &&($options{M}))
		{
			$hpom_ip =~ s/ /\(OM-Ovbbccb\);/g;
			#Adds the (OM-Ovbbccb) to final HPOM ip value
			$hpom_ip = $hpom_ip."(OM-Ovbbccb)";
			$init_csv_header = $init_csv_header.";".$hpom_ip;
		}
		#Adds defined OVR to csv header
		if (($options{b}) && ($options{R}))
		{
			$numOvrString = "NA".";"."NA";
			chomp($ovr_ip);
			$init_csv_header = $init_csv_header.";".$ovr_ip."(OVR-Ovbbccb)".";".$ovr_ip."(OVR-Coda)";
		}
		if (($options{c}) && ($options{M} || $options{R}))
		{
			if ($options{M})
			{
				$hpom_ip_option_c =~ s/ /\(OM-Icmp\);/g;
				#Adds the (OM-Icmp) to final HPOM ip value
				$hpom_ip_option_c = $hpom_ip_option_c."\(OM-Icmp\)";
			}
			if ($options{R})
			{
				$ovr_ip_option_c = $ovr_ip_option_c."(OVR-Icmp)";
			}
			$init_csv_header = $init_csv_header.";".$hpom_ip_option_c.";".$ovr_ip_option_c;
		}
		print "$init_csv_header\n";

		open (my $fh, "<", $nodesFileList)
			or die "Cannot open file $options{L}: $!\n";
		while (<$fh>)
		{
			$nodename = $_;
			chomp($nodename);
			$cmd_timeout = $options{T};
			chomp($cmd_timeout);
			$csv_line = $nodename;

			# Checks if manged node is added within HPOM
			my @return_check_node_in_HPOM = check_node_in_HPOM($nodename);
			my $node_ip_address = $return_check_node_in_HPOM[0];
			my $node_mach_type = $return_check_node_in_HPOM[1];

			# If nodename is not found within HPOM
			if ($return_check_node_in_HPOM[0] eq "1")
			{
				$csv_line = $csv_line.";"."NOT_FOUND".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".$numHpomsString.";".$numOvrString;
			}

			# If nodename is a IP-Message allow node - agentless
			if ($return_check_node_in_HPOM[0] eq "MACH_BBC_OTHER_IP")
			{
				#### ADD HPOMS IN PARM AND OVR
				$csv_line = $csv_line.";"."FOUND".$node_ip_address.";".$node_mach_type.";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA";
			}
			# If nodename is FOUND within HPOM
			if ( ($return_check_node_in_HPOM[0] ne "1") && ($return_check_node_in_HPOM[0] ne "MACH_BBC_OTHER_IP") )
			{
				$csv_line = $csv_line.";"."FOUND".";".$node_ip_address.";".$node_mach_type;

				#Check if HPOM can communicate to node 383
				$result_testOvdeploy_HpomToNode_383 = testOvdeploy_HpomToNode_383($nodename, $cmd_timeout);

				#HPOM can connect 383 to node
				if ($result_testOvdeploy_HpomToNode_383 == 0)
				{
					$csv_line = $csv_line.";"."OK";
					#Checks if HPOM has SSL connection to managed node (to execute remote commands)
					$return_testOvdeploy_HpomToNode_SSL = testOvdeploy_HpomToNode_SSL($nodename, $cmd_timeout);
					#Get node's system OS data if SSL OK to managed node
					if ($return_testOvdeploy_HpomToNode_SSL == 1)
					{
						$csv_line = $csv_line.";"."NOK".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".$numHpomsString.";".$numOvrString;
					}
					if ($return_testOvdeploy_HpomToNode_SSL == 0)
					{
						$csv_line = $csv_line.";"."OK";
						@return_getNodeSysData = getNodeSysData($nodename);
						#Append to csv line OS system data
						foreach my $os_value (@return_getNodeSysData)
						{
							$csv_line = $csv_line.";".$os_value;
						}
					}
				}
				#HPOM can't connect 383 to node
				if ($result_testOvdeploy_HpomToNode_383 == 1)
				{
					### ADD OSINDO, HPOMS IN PARM AND OVR
						$csv_line = $csv_line.";"."NOK".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".";"."NA".$numHpomsString.";".$numOvrString;
				}
				#a: Option to check new HPOM port 383 from managed node
				if ($options{a})
				{
					#Check if HPOM IP parameter defined
					if (!$options{M})
					{
						print "Please define the IP of the Management Server! Option -M <mgmt_server_ip>\n";
						exit 1;
					}

					#If SSL OK to managed node check new HPOM port 383 from managed node
					if ($return_testOvdeploy_HpomToNode_SSL == 0)
					{
						foreach my $loop_hpom (@all_HPOMs)
						{
							$result_testOvdeploy_NodeToHPOM_383 = testOvdeploy_NodeToHPOM_383($nodename, $loop_hpom, $cmd_timeout);
							if ($result_testOvdeploy_NodeToHPOM_383 == 0)
							{
								$csv_line = $csv_line.";"."OK";
							}
							if ($result_testOvdeploy_NodeToHPOM_383 == 1)
							{
								$csv_line = $csv_line.";"."NOK";
							}
						}
					}
				}
				#b: Option to check new OVR port 383 from managed node
				if ($options{b})
				{
					#Check if Repoter Server IP parameter defined
					if (!$options{R})
					{
						print "Please define the IP of the Reporter Server! Option -R <rpt_server_ip>\n";
						exit 1;
					}
					$ovr_ip = $options{R};
					chomp($ovr_ip);
					#If SSL OK to managed node check new OVR port 383 and coda from managed node
					if ($return_testOvdeploy_HpomToNode_SSL == 0)
					{
						@testOVRconnection = testOvdeploy_NodeToOVR_383($nodename, $ovr_ip, $cmd_timeout);
						foreach my $testOVRconnection_line (@testOVRconnection)
						{
							chomp($testOVRconnection_line);
							if ($testOVRconnection_line eq "0")
							{
								$csv_line = $csv_line.";"."OK";
							}
							if ($testOVRconnection_line eq "99")
							{
								$csv_line = $csv_line.";"."NOK";
							}
						}
					}
				}
				if ($options{c})
				{
					if (!$options{M} && !$options{R})
					{
							print "Please define the IP of the Management Server (parameter -M \"<hpom1 hpom2 ... hpom3>\") and/or Reporter Server (parameter -R <rpt_server_ip>)\n";
							exit 1;
					}
					if ($return_testOvdeploy_HpomToNode_SSL == 0)
					{
						if ($options{M})
						{
							foreach my $loop_hpom2 (@all_HPOMs)
							{
								chomp($loop_hpom2);
								$results_icmp_hpom = icmp_to_host_test($nodename, $loop_hpom2, $node_mach_type, "3", "1024", $cmd_timeout);
								$results_icmp_all = $results_icmp_all.";".$results_icmp_hpom;
							}
						}
						if ($options{R})
						{
							$results_icmp_ovr = icmp_to_host_test($nodename, $ovr_ip, $node_mach_type, "3", "1024", $cmd_timeout);
							$results_icmp_all = $results_icmp_all.";".$results_icmp_ovr;
						}
					}
					$csv_line = $csv_line.$results_icmp_all;
					$results_icmp_all = "";
				}
			}
			#print "$results_icmp_all\n";
			print "$csv_line\n";
			#Cleans $return_testOvdeploy_HpomToNode_SSL for next managed node
			$return_testOvdeploy_HpomToNode_SSL = 99;
		}
}

sub HELP_MESSAGE()
{
	print "\nUsage: perl hpom_migration_audit.pl -[abc] -M \"<mgmt_server_ip>\" -R <rpt_server_ip> -L <file_with_servers_list>\n\n";
	print "Mandatory parameters per option:\n";
	print "	Test connectivity to HPOM's Ovbbccb process:\n";
	print "	 -a:	-M \"<mgmt_server_ip>\"\n";
	print "	Test connectivity to OVR's Ovbbccb/Coda processes:\n";
	print "	 -b:	-R <rpt_server_ip>\n";
	print "	Test ICMP to HPOM and/or OVR server\(s\)\n";
	print "	 -c:	-M \"<mgmt_server_ip>\"|-R <rpt_server_ip>\n";
	print "	HPOM\(s\) value:\n";
	print "	 -M \"<mgmt_server_ip>\":	For multiple values, separate them using a space between them.\n";
	print "For all options:\n";
	print "	-L <file_with_servers_list>\n";
	print "Optional:\n";
	print "	-T <timeout_miliseconds>\n";
	print "Default values:\n";
	print "	-T 3000\n";
	print "\n";
}
