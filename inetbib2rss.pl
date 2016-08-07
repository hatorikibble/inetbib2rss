#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;

use LWP::Simple;
use HTML::TreeBuilder::XPath;
use XML::RSS;

my $InetBibArchiv = "http://www.inetbib.de/listenarchiv/";
my $RssOutputFile = "feed.xml";
my $Rss = XML::RSS->new(version=>'1.0');

$Rss->channel(
    title=>'InetBib Listenarchiv',
    description=>'Die Mailingliste als RSS-Feed');

print $Rss->as_string();
my $content = get($InetBibArchiv);

#print $content;

my  $root = HTML::TreeBuilder->new_from_content($content);

#print $root->as_XML_indented;

my $url = undef;
my @messages = $root->findnodes('//body/ul/ul/li');

foreach my $msg ($root->findnodes('//body/ul/ul/li')){
    print $msg->findvalue('.');
    $url = $msg->findvalue('./strong/a/@href');
    print "\n";
}


