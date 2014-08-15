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

	my @proxies;
	while( s/^([\w.]+), // ) {
		push @proxies, $1;
	}

	my ($ip, $odate, $full_req, $resp, $sz, $refer) = /^(\S+) \S+ \S+ \[([^\]]*)\] "([^"]*)" (\S*) (\S*) "([^"]*)"/;
	my ($method, $uri, $protocol) = $full_req =~ /^[A-Z]+ / ?
		split ' ', $full_req :
		qw(<UNDEF> <UNDEF> <UNDEF>);
	my $qparam = $uri =~ s/\?(.*)// ? $1 : undef;

	my ($date, $time) = parse_date($odate);

	$r{'05 day'}{$date}++;
	$r{'10 ip'}{$ip}++;
	$r{'20 response'}{$resp}++;
	$r{'25 referer'}{$refer}++;

	if ($resp < 400) {
		$r{'35 good_req'}{$uri}++;
		$r{'45 good_ref'}{"$refer => ".$uri}++ if $refer ne '-';
	} else {
		$r{'40 bad_req'}{"$resp: ".$uri}++;
		$r{'45 bad_ref'}{"$refer => ".$uri}++ if $refer ne '-';
	}

	if ($gi) {
		my $geo = $gi->country_code_by_addr($ip) || '??';
		$r{'12 geo'}{$geo}++;
		$r{'22 geo_resp'}{"$geo $resp"}++;
	}

}

for my $k ( grep { $gi || !(/geo/) } sort keys %r) {
	my $uniq = scalar(keys %{$r{$k}});
	my @top = top($r{$k});
	next if !@top;
	my $width = max map { length $_ } @top;
	$width = 64 if $width > 64;
	my $pk = $k =~ /^[0-9]* (.*)/ ? $1 : $k;
	print "$pk ($uniq unique):\n";
	printf "%-${width}.${width}s ... %d\n", $_, $r{$k}{$_} for @top;
	print "\n";
};

