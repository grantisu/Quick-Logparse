#!/usr/bin/env perl

use strict;
use warnings;

use List::Util qw(max);
use DateTime;
use HTTP::Request;

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

@mo_map{qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)} = 1 .. 12;
# 24/Mar/2014:07:25:18 -0400
sub parse_date {
	my ($date) = @_;

	my ($dy, $mo, $yr, $hr, $mn, $sc, $tz) = $date =~ qr|^(\d*)/(\w*)/(\d*):(\d*):(\d*):(\d*) (.*)|;

	DateTime->new(
	year      => $yr,
	month     => $mo_map{$mo},
	day       => $dy,
	hour      => $hr,
	minute    => $mn,
	second    => $sc,
	time_zone => $tz
	);
}

while(<>) {
	my $proxy = s/^([\w.]+), // ? $1 : undef;
	my ($ip, $date, $full_req, $resp, $sz, $refer) = /^(\S+) \S+ \S+ \[([^\]]*)\] "([^"]*)" (\S*) (\S*) "([^"]*)"/;
	my $req = HTTP::Request->parse($full_req);
	my $uri = $req->uri // '<UNDEF>';
	$uri =~ s/\?$//;

	$date = parse_date($date);

	$r{day}{$date->ymd}++;
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
	my $width = max map { length $_ } @top;
	print "$k ($uniq unique):\n";
	printf "%-${width}s ... %d\n", $_, $r{$k}{$_} for @top;
	print "\n";
};

