#!/usr/bin/perl

use strict;
use CGI;
use LWP::Simple;
use LWP::UserAgent;
use HTTP::Cookies;

#######################################################################
# Start Variables and Constands

my ($cj,$op,$lurl,$br,$res,$req,$purl,$css,$prms,@keys,
    $user,$pass,@lines,$nurl,$pguid,$q,$v);

$CGI::POST_MAX=1024 * 100; # max 100K posts
$CGI::DISABLE_UPLOADS = 1; # no uploads

# End Variables and Constands
#######################################################################

#######################################################################
# Start Configuration

# Credentials
$user	=	"";
$pass	=	"";

# Cookie Jar location
$cj	=	"/tmp/cookie";

# login URL
$lurl	=	'http://helpdesk.shands.ufl.edu/WebdeskLogin/Logon/Logon.rails';

# Portal group guid - just in case it changes
$pguid	=	'3c78861a-44b8-4f58-925f-bd8aba8b72fa';

# Portal queue URL
$purl	=	'http://helpdesk.shands.ufl.edu/WebdeskLogin/Query/List.rails?class_name=IncidentManagement.Incident&query=_IncidentsByStatus&page_size=50&attributes=Id,Title,CreationDate,Status.Title:Status&sort_by=Id&filter-Equals-Status-=&filter-Equals-CurrentAssignment.User-=&filter-Equals-CurrentAssignment.Group-='.$pguid;

# URL to notes
$nurl	=	'http://helpdesk.shands.ufl.edu/WebdeskLogin/object/open.rails?class_name=IncidentManagement.Incident&key=';

# Create a browser / user agent object - lets mimic firefox
$br = LWP::UserAgent->new;
$br->agent("User-Agent: Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.8.1.12) Gecko/20080201 Firefox/2.0.0.12");

# Make it follow redirects. Doesn't by default
push @{ $br->requests_redirectable }, 'POST';

# Create cookie jar object
$cj = HTTP::Cookies->new(
  file => $cj,
  autosave => 1,
  ignore_discard => 1
);

# Assign our browser object to our cookie jar
$br->cookie_jar($cj);

# End Configuration
#######################################################################

#######################################################################
# Start Output

# Get passed variables
$q = CGI->new;
$v = $q->param('x');

# Output
if ($v eq 'h'){
  &html;
} elsif ($v eq 'r'){
  &rss;
} else {
  print "Content-type: text/html\n\n";
  print "These aren't the droids you're looking for...";
}

# End Output
#######################################################################

#######################################################################
# Start Subrioutines

# parse notes - pass in the key
sub notes {

  my $res = &gcontent($nurl.$_[0]);
  my $note = $res->content;
  my (%ret);

  if ($note =~ /id='mainForm-Description'.+\>(.+)\<\/textarea\>/ ){
    $ret{'DESC'} = $1;
  }
  if ($note =~ /id='mainForm-ResponseLevelTitleDisplay' value='([^']+)'/){
    $ret{'LEVEL'} = $1;
  }
  if ($note =~ /id='mainForm-RaiseUserTitleDisplay' value='([^']+)'/){
    $ret{'USER'} = $1;
  }
  if ($note =~ /name='RaiseUser.EMailAddress' value='([^']+)'/){
    $ret{'EMAIL'} = $1;
  }
  if ($note =~ /name='RaiseUser._Department' value='([^']+)'/){
    $ret{'DEPT'} = $1;
  }
  if ($note =~ /name='RaiseUser.Phone' value='([^']+)'/){
    $ret{'PHONE'} = $1;
  }
  if ($note =~ /id="contentTitleText"\>[^\d]+(\d+)\<\/span\>/){
    $ret{'INCDT'} = $1;
  }

  return %ret;

}

# Authenticate
sub login {

  my($u,$p) = @_;

  $res = $br->post($lurl,
    [ 
      'Ecom_User_ID' 		=> $u,
      'Ecom_User_Password' 	=> $p
    ]
  );

  return $res;

}

# GET Content
sub gcontent {

  my($url) = @_;

  $res = $br->get($url);

  return $res;

}

# CSS Code
sub css {

print  <<EOF;

<style type="text/css" media=screen>

.listBody {
	border: 1px solid black;
}

.listBodyCell {
	background-color: pink;
	padding: 10px;
	font-family: arial, sans-serif;
}

</style>
EOF

}

sub rss {

  &process;

  # Start output
  print "Content-type: application/rss+xml\n\n";
  print "<?xml version=\"1.0\" ?>\n";
  print "<rss version=\"2.0\">\n";
  print "<channel>\n";

  print "<title>Ticket Queue</title>\n";
  print "<description>View your tickets</description>\n";

  # do work
  my $x=0;
  foreach (@lines){
    s/<[^>]+>/\*/g; #strip out the tags
    s/\*\*/ - /g;
    my @line = split(/-/);
    my %hash = &notes($keys[$x]);
    print "<item>\n";
    print "<title>".$line[3]." - $hash{'LEVEL'} - ".$line[2]." - ".$line[4]."</title>\n";
    print "<description><![CDATA[\n";
    if (exists($hash{'INCDT'})){ print "Incident: $hash{'INCDT'}<br/>\n"; }
    if (exists($hash{'DEPT'})){ print "Dept: $hash{'DEPT'}<br/>\n"; }
    if (exists($hash{'LEVEL'})){ print "Level: $hash{'LEVEL'}<br/>\n"; }
    if (exists($hash{'USER'})){ print "User: $hash{'USER'}<br/>\n"; }
    if (exists($hash{'EMAIL'})){ print "Email: $hash{'EMAIL'}<br/>\n"; }
    if (exists($hash{'PHONE'})){ print "Phone: $hash{'PHONE'}<br/>\n"; }
    if (exists($hash{'DESC'})){ print "$hash{'DESC'}\n"; }
    print "]]></description>\n";
    print "</item>\n";
    $x++;
  }

  # start test
  #print "<item>\n";
  #print "<title>User Agent</title>\n";
  #print "<description><![CDATA[\n";
  #print $q->user_agent();
  #print "]]></description>\n";
  #print "</item>\n";
  # end test

  print "</channel>\n";
  print "</rss>\n";

}

sub html {

  &process;

  # Start output
  print "Content-type: text/html\n\n";
  print "<html>\n";
  print "<head>\n";
  #&css;
  print "</head>\n";
  print "<body>\n";

  # do work
  my $x=0;
  foreach (@lines){
    s/<[^>]+>/\*/g; #strip out the tags
    s/\*\*/ - /g;
    my @line = split(/-/);
    print "<b>".$line[2]."</b><br>\n";
    print $line[3]." - ".$line[4]."<br>\n";
    my %hash = &notes($keys[$x]);
    if (exists($hash{'INCDT'})){ print "Incident: $hash{'INCDT'}<br>\n"; }
    if (exists($hash{'DEPT'})){ print "Dept: $hash{'DEPT'}<br>\n"; }
    if (exists($hash{'LEVEL'})){ print "Level: $hash{'LEVEL'}<br>\n"; }
    if (exists($hash{'USER'})){ print "User: $hash{'USER'}<br>\n"; }
    if (exists($hash{'EMAIL'})){ print "Email: <a href='mailto:".$hash{'EMAIL'}."''>".$hash{'EMAIL'}."</a><br>\n"; }
    if (exists($hash{'PHONE'})){ print "Phone: $hash{'PHONE'}<br>\n"; }
    if (exists($hash{'DESC'})){ print "Desc: $hash{'DESC'}<br>\n"; }
    print "<br><br>\n";;
    $x++;
  }

  print "</body>\n";
  print "</html>\n";
  # End Output

}

# login and fetch stuff to lists
sub process {

  # Authenticate
  &login($user,$pass);

  # get portal queue content
  $res = gcontent($purl);
  $op = $res->content;

  # parse the portal queue content and assign 
  # various stuff to variables
  foreach (split /\n/ ,$op) {
    if (/listBody/){
      s/<tr/\n<tr/g;
      s/tr>/tr>\n/g;
      @lines = /(<tr.*)/gm;
      @keys = /key:.'(.{36})'./gm;
    }
  }

}

# End Subroutines
#######################################################################
