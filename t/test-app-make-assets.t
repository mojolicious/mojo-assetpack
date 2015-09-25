use t::Helper;
use Mojolicious::Plugin::AssetPack;

for my $file (
  qw(
  _assetpack.map
  test-850535cb2326f7f53634bcd5de830895.css
  myapp-850535cb2326f7f53634bcd5de830895.min.css
  )
  )
{
  ok !-e File::Spec->catfile('t', 'public', 'packed', $file), "not generated $file";
}

Mojolicious::Plugin::AssetPack->test_app("t::Dynamic");

for my $file (
  qw( _assetpack.map test-850535cb2326f7f53634bcd5de830895.css myapp-850535cb2326f7f53634bcd5de830895.min.css ))
{
  ok -e File::Spec->catfile('t', 'public', 'packed', $file), "generated $file";
}

done_testing;
