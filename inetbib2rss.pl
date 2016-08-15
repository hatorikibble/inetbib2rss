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
my $message = undef;
my $desc = undef;

my $DateParser = DateTime::Format::Strptime->new(
    pattern  => '%a, %e %b %Y %H:%M:%S %z (%Z)',
    locale   => 'en',
    on_error => 'croak',
);

foreach my $l ( split( '\n', $content ) ) {
    if ( $l =~
/<LI><strong><a name="\d+" href="(.*?)">(.*?)<\/a><\/strong>, (.*?)<\/LI>/
      )
    {
        $url     = $InetBibArchiv . $1;
	$subject = $2;
        $author  = $3;
	$message = get($url);
	if ($message =~ /Body-of-Message-->(.*?)<!--X-Body-of-Message/s){
	    $desc = $1;
	    $desc =~ s/<\/*pre.*?>//g;
	}else{
	    $desc = undef;
	}
	if ($message =~ /X-Date: (.+?) --/){
	    $date = $DateParser->parse_datetime($1);
	}else{
	    $date = undef;
	}	
        $Rss->add_item(
            title => $subject,
            link  => $url,
	    description => $desc,
            dc    => {
                creator => $author,
                date    => DateTime::Format::W3CDTF->format_datetime($date)
            }
        );
    }
}

print $Rss->as_string();

