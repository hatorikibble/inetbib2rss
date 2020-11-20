#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;

use DateTime;
use DateTime::Format::W3CDTF;
use DateTime::Format::Strptime;
use HTTP::Tiny;
use XML::RSS;

my $InetBibArchiv = "https://www.inetbib.de/listenarchiv/";
my $Rss           = XML::RSS->new( version => '1.0' );

$Rss->channel( title       => 'InetBib Listenarchiv',
               description => 'Die Mailingliste als RSS-Feed',
               link        => $InetBibArchiv
);

my $response         = undef;
my $content          = undef;
my $date             = undef;
my $url              = undef;
my $subject          = undef;
my $author           = undef;
my $message_response = undef;
my $message          = undef;
my $desc             = undef;

my $DateParser =
    DateTime::Format::Strptime->new( pattern  => '%a, %e %b %Y %H:%M:%S %z',
                                     locale   => 'en',
                                     on_error => 'croak',
    );

# Thu, 19 Nov 2020 17:42:48 +0100

$response = HTTP::Tiny->new->get($InetBibArchiv);

if ( $response->{success} ) {
    $content = $response->{content};
    foreach my $l ( split( '\n', $content ) ) {
        if ( $l
            =~ /<LI><strong><a name="\d+" href="(.*?)">(.*?)<\/a><\/strong>, (.*?)<\/LI>/
            )
        {
            $url              = $InetBibArchiv . $1;
            $subject          = $2;
            $author           = $3;
            $message_response = HTTP::Tiny->new->get($url);
            if ( $message_response->{success} ) {
                $message = $message_response->{content};
            }
            else {
                die "Konnte URL $url nicht abrufen!";
            }
            if ( $message =~ /Body-of-Message-->(.*?)<!--X-Body-of-Message/s ) {
                $desc = $1;
            }
            else {
                $desc = undef;
            }

            # <!--X-Date: Thu, 19 Nov 2020 17:42:48 +0100 -->
            if ( $message =~ /X-Date: (.+?) --/ ) {

                $date = $DateParser->parse_datetime($1);
            }
            else {
                $date = undef;
            }

            $Rss->add_item(
                    title       => $subject,
                    link        => $url,
                    description => $desc,
                    dc          => {
                        creator => $author,
                        date => DateTime::Format::W3CDTF->format_datetime($date)
                    }
            );
        } ## end if ( $l =~ ...)
    } ## end foreach my $l ( split( '\n'...))

    print $Rss->as_string();
} ## end if ( $response->{success...})
else {
    die "Konnte URL $InetBibArchiv nicht abrufen!";
}
