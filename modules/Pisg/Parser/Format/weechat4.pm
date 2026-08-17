package Pisg::Parser::Format::weechat4;

# Documentation for the Pisg::Parser::Format modules is found in Template.pm
#
# Parser for current WeeChat log format (tested against WeeChat >= 3.x,
# including the 4.x series). WeeChat's default logger.file.time_format
# changed from "%Y-%m-%d %H:%M:%S" (matched by weechat3.pm) to
# "%@%F %T.%fZ", which appends fractional seconds and a trailing "Z" to
# the timestamp, e.g.:
#
#   2026-08-17 12:34:56.123456Z	nick	hello there
#   2026-08-17 12:34:56.123456Z	-->	nick (user@host) has joined #channel
#   2026-08-17 12:34:56.123456Z	<--	nick (user@host) has quit (Ping timeout)
#   2026-08-17 12:34:56.123456Z	 *	nick waves
#
# The message bodies for joins/quits/kicks/nickchanges/topics/modes are
# unchanged from the weechat3 format, so this module reuses that logic and
# only relaxes the timestamp portion of the regexes to tolerate the
# optional ".ffffff" fractional seconds and trailing "Z".

use strict;
$^W = 1;

sub new
{
    my ($type, %args) = @_;
    my $self = {
        cfg => $args{cfg},
        normalline => '^\d+-\d+-\d+ (\d+):\d+:\d+(?:\.\d+)?Z?\t[@%+~&]?([^ <-]\S+)\t(.*)',
        actionline => '^\d+-\d+-\d+ (\d+):\d+:\d+(?:\.\d+)?Z?\t \*\t(\S+) (.*)',
        thirdline  => '^\d+-\d+-\d+ (\d+):(\d+):\d+(?:\.\d+)?Z?\t(?:--|<--|-->)\t(\S+) (\S+) (\S+) (\S+) (\S+)(.*)',
    };

    bless($self, $type);
    return $self;
}

sub normalline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{normalline}/o) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $3;

        return \%hash;
    } else {
        return;
    }
}

sub actionline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{actionline}/o) {

        $hash{hour}   = $1;
        $hash{nick}   = $2;
        $hash{saying} = $3;

        return \%hash;
    } else {
        return;
    }
}

sub thirdline
{
    my ($self, $line, $lines) = @_;
    my %hash;

    if ($line =~ /$self->{thirdline}/o) {

        $hash{hour} = $1;
        $hash{min}  = $2;
        $hash{nick} = $3;

        if (($4.$5) eq 'haskicked') {
            $hash{nick} = $6;
            $hash{kicker} = $3;

        } elsif ($4.$5.$6 eq 'haschangedtopic') {
            # Matches both "...to "newtopic"" (fresh topic) and
            # "...from "oldtopic" to "newtopic"" (topic change): grab the
            # text inside the last pair of quotes.
            if ($8 =~ /"([^"]*)"\s*$/) {
                $hash{newtopic} = $1;
            }

        } elsif ($3 eq 'Mode') {
            $hash{newmode} = substr($5, 1);
            $hash{nick} = $8 || $7;
            $hash{nick} =~ s/.* (\S+)$/$1/; # Get the last word of the string

        } elsif (($5.$6) eq 'hasjoined') {
            $hash{newjoin} = $3;

        } elsif (($5.$6) eq 'nowknown') {
            if ($8 =~ /^\s+(\S+)/) {
                $hash{newnick} = $1;
            }
        }

        return \%hash;

    } else {
        return;
    }
}

1;
