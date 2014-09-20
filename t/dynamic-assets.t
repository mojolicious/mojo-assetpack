#!/usr/bin/env perl
package TestApp;
use Mojo::Base 'Mojolicious';
use Test::More;

sub startup {
  my $app = shift;
  $app->plugin('AssetPack');

  my $r = $app->routes;
  $r->get('/test.css')->to(
    cb => sub {
      shift->render(text => 'a[href]{ border: 1px solid black; }', format => 'css');
    }
  )->name('mystyle');

  $r->get('/')->to(
    cb => sub {
      shift->render(inline => '%= asset "/myapp.css"', format => 'html');
    }
  )->name('mystyle');

  is($app->url_for('mystyle'), '/test.css', 'style');

  # Start event loop if necessary
  $app->asset(
    '/myapp.css' => $app->url_for('mystyle')
  );
};

package main;
use lib '../lib','lib';
use Test::More;
use Test::Mojo;

use strict;
use warnings;

my $t = Test::Mojo->new;

$t->app(TestApp->new);

is($t->app->url_for('mystyle'), '/test.css', 'CSS Asset');

$t->get_ok('/test.css')
  ->status_is(200)
  ->content_type_is('text/css')
  ->content_is(q!a[href]{ border: 1px solid black; }!);

$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr!<link href=".*?/test\.css" rel="stylesheet" />!);

done_testing;
