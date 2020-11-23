#!/usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;

use DateTime;
use DateTime::Format::W3CDTF;
use DateTime::Format::Strptime;
use Getopt::Long;
use HTTP::Tiny;
use Log::Any qw ($log);
use Log::Any::Adapter;
use Pod::Usage;
use XML::RSS;

$ENV{LOG_PREFIX} = "elapsed";
Log::Any::Adapter->set( 'Screen', min_level => 'debug', stderr => 0, );

my $InetBibArchiv = "https://www.inetbib.de/listenarchiv/";

my $help    = 0;
my $outfile = undef;
my $limit   = undef;

sub createRssFile {
    my $Rss              = XML::RSS->new( version => '1.0' );
    my $response         = undef;
    my $i                = 0;
    my $content          = undef;
    my $date             = undef;
    my $url              = undef;
    my $subject          = undef;
    my $author           = undef;
    my $message_response = undef;
    my $message          = undef;
    my $desc             = undef;
    my $error            = undef;

    my $DateParser =
        DateTime::Format::Strptime->new( pattern  => '%a, %e %b %Y %H:%M:%S %z',
                                         locale   => 'en',
                                         on_error => 'croak',
        );

    # Thu, 19 Nov 2020 17:42:48 +0100

    $log->debugf( "Fetching %d items from '%s'", $limit, $InetBibArchiv );
    $response = HTTP::Tiny->new->get($InetBibArchiv);

    if ( $response->{success} ) {

        $Rss->channel( title       => 'InetBib Listenarchiv',
                       description =>
                           sprintf( 'Die Mailingliste als RSS-Feed (Stand: %s)',
                                 DateTime->now(time_zone=>'Europe/Berlin')->strftime("%d.%m.%Y %H:%M:%S") ),
                       link => $InetBibArchiv
        );
        $content = $response->{content};
        foreach my $l ( split( '\n', $content ) ) {
            if ( $l
                =~ /<LI><strong><a name="\d+" href="(.*?)">(.*?)<\/a><\/strong>, (.*?)<\/LI>/
                )
            {
                next if ( $i >= $limit );    # Limit erreicht?
                $i++;
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
                if ( $message
                     =~ /Body-of-Message-->(.*?)<!--X-Body-of-Message/s )
                {
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
                $log->debugf( "Adding item %d: %s: \"%s\" (%s)",
                              $i, $author, $subject, $date );
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
        $log->infof( "Fetched %d items", $i );

        open( F, ">", $outfile )
            or die_with_error(
                       sprintf( "Kann '%s' nicht oeffnen: %s", $outfile, $! ) );
        print F $Rss->as_string();
        close(F)
            or die_with_error(
                    sprintf( "Kann '%s' nicht schliessen: %s", $outfile, $! ) );
        $log->infof( "created '%s' successfully", $outfile );
    } ## end if ( $response->{success...})
    else {
        $error
            = sprintf(
                     "ERROR: Konnte URL $InetBibArchiv nicht abrufen: %s (%s)",
                     $InetBibArchiv, $response->{reason}, $response->{status} );
        $log->error($error);
        die $error;
    }

} ## end sub createRssFile

sub die_with_error {
    my $error = shift;
    $log->error( "ERROR: " . $error );
    die $error;
}

######
# Main
######

$log->infof( "Started at '%s'...",
             DateTime->now(time_zone=>'Europe/Berlin')->strftime("%d.%m.%Y %H:%M:%S") );
GetOptions( 'help|?' => \$help, "outfile=s" => \$outfile, "limit=i" => \$limit )
    or pod2usage(2);
pod2usage(1) if $help;

die_with_error("Kein Parameter 'outfile' uebergeben!")
    unless ( defined($outfile) );
$limit = 50 unless ( defined($limit) );

createRssFile();
$log->infof( "Ended at '%s'...", DateTime->now(time_zone=>'Europe/Berlin')->strftime("%d.%m.%Y %H:%M:%S") );
__END__

=head1 NAME

inetbib2rss.pl - RSS Feed aus dem InetBib Mailarchiv erzeugen

=head1 SYNOPSIS

./inetbib2rss.pl -o=/var/www/rss/inetbib.xml -l=10

./inetbib2rss.pl --outfile=/var/www/rss/inetbib.xml --limit 10

=head1 OPTIONS

=over 8

=item * (-o|--outfile)

Name der Datei, in die der RSS-Feed geschrieben werden soll

=item * (-l|--limit)

Anzahl der Einträge die in den Feed geschrieben werden sollen

=item * (-h|--help|-?)

diese Hilfe anzeigen

=back

=cut
