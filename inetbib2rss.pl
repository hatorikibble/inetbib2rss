#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;

use DateTime;
use DateTime::Format::W3CDTF;
use DateTime::Format::Strptime;
use LWP::Simple;
use XML::RSS;

my $InetBibArchiv = "http://www.inetbib.de/listenarchiv/";
my $RssOutputFile = "feed.xml";
my $Rss           = XML::RSS->new( version => '1.0' );

$Rss->channel(
    title       => 'InetBib Listenarchiv',
    description => 'Die Mailingliste als RSS-Feed',
    link        => $InetBibArchiv
);

my $content = get($InetBibArchiv);
my $date    = undef;
my $url     = undef;
my $subject = undef;
my $author  = undef;

my $DateParser = DateTime::Format::Strptime->new(
    pattern  => '%d. %B %Y',
    locale   => 'en',
    on_error => 'croak',
);

foreach my $l ( split( '\n', $content ) ) {

    #print $l;
    if ( $l =~ /<LI><STRONG>(\d+\. \w+ \d{4})<\/STRONG><\/LI>/ ) {
        $date = $DateParser->parse_datetime($1);
    }
    elsif ( $l =~
/<LI><strong><a name="\d+" href="(.*?)">(.*?)<\/a><\/strong>, (.*?)<\/LI>/
      )
    {
        $url     = $InetBibArchiv . $1;
        $subject = $2;
        $author  = $3;
        $Rss->add_item(
            title => $subject,
            link  => $url,
            dc    => {
                creator => $author,
                date    => DateTime::Format::W3CDTF->format_date($date)
            }
        );
    }
}

print $Rss->as_string();

