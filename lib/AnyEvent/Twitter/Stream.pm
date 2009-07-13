package AnyEvent::Twitter::Stream;

use strict;
use 5.008_001;
our $VERSION = '0.01';

use AnyEvent;
use AnyEvent::HTTP;
use JSON;
use MIME::Base64;
use URI;

my %methods = map { $_ => 1 } qw( firehose gardenhose spritzer birddog shadow follow track );
my %handles;

sub new {
    my $class = shift;
    my %args  = @_;

    my $username = delete $args{username};
    my $password = delete $args{password};
    my $method   = delete $args{method};
    my $on_tweet = delete $args{on_tweet};
    my $on_error = delete $args{on_error} || sub { die @_ };
    my $on_eof   = delete $args{on_eof}   || sub {};

    unless ($methods{$method}) {
        return $on_error->("Method $method not available.");
    }

    my $auth = MIME::Base64::encode("$username:$password");

    my $uri = URI->new("http://stream.twitter.com/$method.json");
    $uri->query_form(%args);

    http_get $uri,
        headers => { Authorization => "Basic $auth" },
        on_header => sub {
            my($headers) = @_;
            if ($headers->{Status} ne '200') {
                return $on_error->("$headers->{Status}: $headers->{Reason}");
            }
            return 1;
        },
        want_body_handle => 1, # for some reason on_body => sub {} doesn't work :/
        sub {
            my($handle, $headers) = @_;

            if ($handle) {
                $handles{$handle} = $handle;
                $handle->on_eof(sub {
                    delete $handles{$_[0]};
                    undef $_[0];
                    $on_eof->(@_);
                });
                my $reader; $reader = sub {
                    my($handle, $json) = @_;
                    my $tweet = JSON->new->decode($json);
                    $on_tweet->($tweet);
                    $handle->push_read(line => $reader);
                };
                $handle->push_read(line => $reader);
            }
        };

}

1;
__END__

=encoding utf-8

=for stopwords
API AnyEvent

=for test_synopsis
my($user, $password, @following_ids);

=head1 NAME

AnyEvent::Twitter::Stream - Receive Twitter streaming API in an event loop

=head1 SYNOPSIS

  use AnyEvent::Twitter::Stream;

  # receive updates from @following_ids
  AnyEvent::Twitter::Stream->new(
      username => $user,
      password => $password,
      method   => "follow",
      follow   => join(",", @following_ids),
      on_tweet => sub {
          my $tweet = shift;
          warn "$tweet->{user}{screen_name}: $tweet->{text}\n";
     },
  );

  # track keywords
  AnyEvent::Twitter::Stream->new(
      username => $user,
      password => $password,
      method   => "track",
      keyword  => "Perl,Test,Music",
      on_tweet => sub { },
  );

=head1 DESCRIPTION

AnyEvent::Twitter::Stream is an AnyEvent user to receive Twitter streaming
API, available at L<http://apiwiki.twitter.com/Streaming-API-Documentation>

See L<eg/track.pl> for more client code example.

=head1 AUTHOR

Tatsuhiko Miyagawa E<lt>miyagawa@bulknews.netE<gt>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 SEE ALSO

L<AnyEvent::Twitter>, L<Net::Twitter::Stream>

=cut