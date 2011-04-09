use strict;
use warnings;

use Test::More;

use lib 't/lib';
use Ambikon::IntegrationServer::Test::Proxy qw/ test_proxy /;

# test a basic conf with 1 backend
test_proxy(
    conf => <<'EOC',
theme_from_subsite  mainsite

<subsite mainsite>
  internal_url   http://$host:$port1
  external_path  /
  <theme>
    theme_url    /ambikon_theme
  </theme>
</subsite>
<subsite foo_bar>
  internal_url   http://$host:$port2/monkeys
  external_path  /foo

  <postprocess>
      when content_type:text/html
      with Text::MicroTemplate
  </postprocess>
</subsite>
EOC

    backends => [
        sub {
            my $env = shift;

            return [
                200,
                ['Content-type' => 'text/html'],
                [ <<'EOTHEME' ],
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
  <head>
    <link rel="stylesheet" href="/fictitious/stylesheet.css" />
    <script language="javascript" type="text/javascript">
      JSAN = {};
      JSAN.use = function() {};
      MochiKit = {__export__: false};
    </script>
  </head>
  <body>
    <div id="outercontainer">
      <!-- hi i'm a comment -->
      <a name="top"></a>
      <table id="siteheader" cellpadding="0" cellspacing="0">
        <td>foo</td><td>tool</td><td>bar</td>
      </table>

      <!-- this is a comment here -->
      <ambikon:content />

      <!-- and this is another comment -->
   </div>
  </body>
</html>
EOTHEME
              ];
        },
        sub {
            my $env = shift;

            my %dispatch = (
                '/monkeys/fog' => [
                    200,
                    [ 'Content-type' => 'text/html',
                      'X-bar'  => 'fogbat',
                      'X-zee'  => 'zaz',
                    ],
                    [ <<'EOH' ]],
<html>
  <head>
    <title>This is my title, hihi!</title>
? $ambikon->print_html_head
  </head>
  <body>
? $ambikon->print_html_body_start
    <h1>Important Page</h1>
    <p>This page is so important, you don't even <b>know</b>.</p>
? $ambikon->print_html_body_end
  </body>
</html>
EOH
              );

            return $dispatch{ $env->{PATH_INFO} } || [ 404, [], [$env->{PATH_INFO}.' not found']];;
        },
      ],

    client => sub {
        my $mech = shift;
        $mech->get_ok( '/foo/fog' );
        $mech->content_contains('so important');
        $mech->content_lacks( '$ambikon', 'templating was run' );
    },
  );

done_testing;
exit;

