package Mojolicious::Plugin::Compress;

=head1 NAME

Mojolicious::Plugin::Compress - Compress css, scss and javascript with external tools

=head1 VERSION

0.01

=head1 DESCRIPTION

This plugin will automatically compress scss, less, css and javascript with
the help of external application. The result will be one file with all the
sources combined.

=head1 APPLICATIONS

=head2 less

=head2 sass

=head2 yuicompressor

=head1 SYNOPSIS

In your application:

  use Mojolicious::Lite;
  plugin 'Compress';
  app->start;

In your template:

  %= compress '/js/jquery.min.js', '/js/app.js';
  %= compress '/less/reset.less', '/sass/helpers.scss', '/css/app.css';

NOTE! You need to have one line for each type, meaning you cannot combine
javascript and css sources on one line.

=cut

use strict;
use warnings;

our $VERSION = '0.01';

=head1 METHODS

=head2 startup

=cut

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
