use warnings;
use strict;
use Test::More;
use Test::Mojo;

plan skip_all => 'Not ready for alien host' unless $^O eq 'linux';

{
  use Mojolicious::Lite;
  plugin 'Compress' => { enable => 1, reset => 1 };
  get '/js' => 'js';
}

my $t = Test::Mojo->new;
my @run;

{
  $Mojolicious::Plugin::Compress::APPLICATIONS{js} = 'dummy';
  *Mojolicious::Plugin::Compress::_system = sub {
    push @run, [@_];
    open my $FH, '>', $_[-1];
    print $FH "dummy();\n";
  };

  $t->get_ok('/js')
    ->status_is(200)
    ->content_like(qr{<script src="/compressed/\w+\.js".*}m)
    ;

  is int @run, 1, 'only compressed one file';
  like $run[0][1], qr{a\.js}, 'a.js got compiled';
}

done_testing;
__DATA__
@@ js.html.ep
%= compress '/js/a.js', '/js/already.min.js'
