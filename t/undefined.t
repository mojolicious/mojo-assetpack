use t::Helper;

{
  diag "minify=0";
  my $t = t::Helper->t({ minify => 0 });

  $t->get_ok('/undefined')->status_is(200)->content_like(qr{<!-- Cannot expand});
}

done_testing;

__DATA__
@@ undefined.html.ep
%= asset 'undefined.css'
