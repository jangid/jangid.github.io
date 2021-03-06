#!/usr/pkg/bin/perl

use strict;
use warnings;
use CGI;
use XML::DOM;
use LWP::Simple qw(!head);
use Encode;

# parse the rss content
my $parser =  new XML::DOM::Parser;
my $doc = getXmlDoc();
my $nodes = $doc->getElementsByTagName ("item");
my $n = $nodes->getLength;

# display the content
my $cgi = new CGI;
print $cgi->header();
my $title_date = "";

for(my $i = 0; $i < $n; $i++)
{
    my $node = $nodes->item($i);
    my $date = $node->getElementsByTagName ("pubDate")->item(0)->getFirstChild->getNodeValue;
    $date =~ s/ [[:digit:]]{2}:[[:digit:]]{2}:[[:digit:]]{2} GMT//;
    my $oTitle = $node->getElementsByTagName ("title");
    my $title = "";
    if($oTitle->getLength > 0) {
        $title = $oTitle->item(0)->getFirstChild->getNodeValue;
    }
    my $description = $node->getElementsByTagName ("description")->item(0)->getFirstChild->getNodeValue;
    $description =~ s/<wbr \/>//;
    #my $comment = $node->getElementsByTagName ("comments")->item(0)->getFirstChild->getNodeValue;
    my $link = $node->getElementsByTagName ("link")->item(0)->getFirstChild->getNodeValue;


    if($title_date ne $date) {
        $title_date = $date;
        print $cgi->h1($title_date), "\n";
        print $cgi->hr(), "\n";
    }

    print $cgi->h2($cgi->a({href=>$link}, $title)), "\n";
    print $cgi->p($description), "\n";
    #print $cgi->a({href=>$comment}, "comment"), "\n";
}

# function to check if cache is one hour old
sub getXmlDoc {
    my $iTime = 0;
    if(open(TSTAMP, "rss.tstamp")) {
        $iTime += <TSTAMP>;
    }
    my $doc;

    if(time() > ($iTime + 3600)) {
        #my $xmlFile = get ("http://www.livejournal.com/users/jangid/data/rss");
        my $xmlFile = get ("http://pipes.yahoo.com/pipes/pipe.run?_id=IFIIVHhO3BGmNJZyjtzu1g&_render=rss");
        $doc = $parser->parse ($xmlFile);
        close(TSTAMP);
        open(TSTAMP, ">rss.tstamp");
        print TSTAMP time();
        open(CACHE, ">rss.xml");
        print CACHE $xmlFile;
        close(CACHE);
    }
    else {
        $doc = $parser->parsefile ("rss.xml");
    }
    close(TSTAMP);

    return $doc;
}
