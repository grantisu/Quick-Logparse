#!/usr/bin/env perl

use strict;
use warnings;

use List::Util qw(max);
use POSIX qw(mktime strftime);

my ($gi, %r, %mo_map);

if (0) {
	require Geo::IP::PurePerl;
	$gi = Geo::IP::PurePerl->new(Geo::IP::PurePerl::GEOIP_MEMORY_CACHE());
}

sub top {
	my ($h, $n) = @_;
	$n ||= 5;
	grep defined, (sort { $h->{$b} <=> $h->{$a} } keys %$h)[0..($n-1)];
}

@mo_map{qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)} = 0 .. 11;
# 24/Mar/2014:07:25:18 -0400
sub parse_date {
	my ($date) = @_;

	my ($dy, $mo, $yr, $hr, $mn, $sc, $tz) = $date =~ qr|^(\d*)/(\w*)/(\d*):(\d*):(\d*):(\d*) (.*)|;

	local $ENV{TZ} = $tz;
	split ' ', strftime("%F %T", gmtime POSIX::mktime($sc, $mn, $hr, $dy, $mo_map{$mo}, $yr-1900, -1, -1, -1));
}

while(<>) {
	my $proxy = s/^([\w.]+), // ? $1 : undef;
	my ($ip, $odate, $full_req, $resp, $sz, $refer) = /^(\S+) \S+ \S+ \[([^\]]*)\] "([^"]*)" (\S*) (\S*) "([^"]*)"/;
	my ($method, $uri, $protocol) = split ' ', $full_req;
	my $qparam = $uri =~ s/\?(.*)// ? $1 : undef;

	my ($date, $time) = parse_date($odate);

	$r{day}{$date}++;
	$r{ip}{$ip}++;
	$r{uri}{$uri}++;
	$r{resp}{$resp}++;
	$r{refer}{$refer}++;

	$r{proxy}{$proxy}++ if $proxy;
	if ($resp eq '200') {
		$r{good_req}{$uri}++;
		$r{good_ref}{"$refer => ".$uri}++ if $refer ne '-';
	} else {
		$r{bad_req}{"$resp: ".$uri}++;
		$r{bad_ref}{"$refer => ".$uri}++ if $refer ne '-';
	}

	if ($gi) {
		my $geo = $gi->country_code_by_addr($ip) || '??';
		$r{geo}{$geo}++;
		$r{geo_resp}{"$geo $resp"}++;
		# $r{geo_hr}{"$geo - ".$date->hour}++;
	}

}

for my $k ( grep { $gi || !(/geo/) } qw(
day
ip
refer
resp
geo
geo_resp
good_req
bad_req
good_ref
bad_ref
)) {
	my $uniq = scalar(keys %{$r{$k}});
	my @top = top($r{$k});
	next if !@top;
	my $width = max map { length $_ } @top;
	$width = 64 if $width > 64;
	print "$k ($uniq unique):\n";
	printf "%-${width}.${width}s ... %d\n", $_, $r{$k}{$_} for @top;
	print "\n";
};

