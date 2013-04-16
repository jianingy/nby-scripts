#!/home/tops/bin/perl -i -w

# filename   : install-ipv6.pl
# created at : 2012年08月01日 星期三 21时08分45秒
# author     : Jianing Yang <shiqian@taobao.com>

use strict;
use warnings;

use Getopt::Std;

use vars '$opt_h', '$opt_i', '$opt_l';

BEGIN {
	if (!getopts('h:i:l') || (!$opt_l && (!$opt_h || !$opt_i))) {
		print STDERR "Usage: $0 -h hostname  -i address\n";
		print STDERR "Install IPv6 address on target host\n";
		exit;
	}

	if (!$opt_l) {
		system("sudo scp $0 $opt_h:/tmp/.install-ipv6.pl");
		system("sudo ssh $opt_h /tmp/.install-ipv6.pl -l -h '$opt_h' -i '$opt_i'");
	    exit;
	}
}
sub pick_address 
{
	$opt_i;
}

sub pick_gateway 
{
	return "fe80::221:1bff:fe8e:5c0";
}

##############################################################################
#
# EDIT /etc/modprobe.*
#
##############################################################################
{
	my @modprobes = glob("/etc/modprobe.d/*");
	push @modprobes, "/etc/modprobe.conf";
	local @ARGV = @modprobes;
	while (<>) {
		s/alias\s+net-pf-10\s+off\s+//g;
		s/alias\s+ipv6\s+off\s+//g;
		s/options\s+ipv6\s+disable=1\s+//g;
		print;
	}
}

##############################################################################
#
# EDIT /etc/sysconfig/network
#
##############################################################################
{
	local @ARGV = qw(/etc/sysconfig/network);
	while (<>) {
		s/NETWORKING_IPV6=.+[\r\n]?//g if m/^NETWORKING_IPV6=/;
		print;
		print "NETWORKING_IPV6=yes\n" if eof;
	}
}

##############################################################################
#
# EDIT /etc/sysconfig/network-scripts/ifcfg-*
#
##############################################################################
{
	my $iface = undef;
	$iface = $1 if (qx(/sbin/ip ro show exact 0.0.0.0/0) =~ /dev ([\w\d]+)/);
	chomp $iface;
	die "cannot find main routing interface" unless $iface;
	local @ARGV = qq(/etc/sysconfig/network-scripts/ifcfg-$iface);

	my $my_address = &pick_address;
	my $my_gateway = &pick_gateway;
	die "ipv6 address not found" unless $my_address;
	die "ipv6 gateway not found" unless $my_gateway;
	my $config = <<EOF;
IPV6INIT=yes
IPV6ADDR=$my_address
IPV6_DEFAULTGW=$my_gateway
EOF
	while(<>) {
		s/IPV6INIT=.+[\r\n]?//g if (m/^IPV6INIT=/);
		s/IPV6ADDR=.+[\r\n]?//g if (m/^IPV6ADDR=/);
		s/IPV6_DEFAULTGW=.+[\r\n]?//g if (m/^IPV6_DEFAULTGW=/);
		print;
		print $config if eof;
	}
}
