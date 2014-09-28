#!/usr/bin/env perl
package TestApp;
use Mojo::Base 'Mojolicious';
use Test::More;

sub startup {
  my $app = shift;
  $app->plugin('AssetPack');
  $app->plugin(Config => {
    default => {
      bg_color => 'blue'
    }
  });

  my $r = $app->routes;
  $r->get('/test.css')->to(
    cb => sub {
      my $c = shift;
      $c->render(
	text => 'body { background-color: ' . $c->config('bg_color') . ' }',
	format => 'css'
      );
    }
  )->name('mystyle');

  $r->get('/')->to(
    cb => sub {
      shift->render(
	inline => '%= asset "/myapp.css"',
	format => 'html'
      );
    }
  )->name('mystyle');

  is($app->url_for('mystyle'), '/test.css', 'style');

  # Start event loop if necessary
  $app->asset(
    '/myapp.css' => $app->url_for('mystyle')
  );
};

package main;
use strict;
use warnings;
use lib '../lib','lib';
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new;

$t->app(TestApp->new);

is($t->app->url_for('mystyle'), '/test.css', 'CSS Asset');

$t->get_ok('/test.css')
  ->status_is(200)
  ->content_type_is('text/css')
  ->content_is(q!body { background-color: blue }!);

$t->get_ok('/')
  ->status_is(200)
  ->content_like(qr!<link href=".*?/test\.css" rel="stylesheet" />!);

done_testing;
