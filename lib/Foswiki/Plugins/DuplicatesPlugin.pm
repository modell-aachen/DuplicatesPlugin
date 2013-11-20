# See bottom of file for default license and copyright information

package Foswiki::Plugins::DuplicatesPlugin;

use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Digest::SHA1;

#use version; our $VERSION = version->declare("v1.0.0_001");
our $VERSION = "0.0.1"; # XXX

our $RELEASE = '0.0.2';

# One line description of the module
our $SHORTDESCRIPTION = 'Check if a file was attached twice.';

our $NO_PREFS_IN_TOPIC = 1;

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    Foswiki::Func::registerRESTHandler(
        'hashify', \&_restHashify,
        authenticate => 1, http_allow => 'GET' );

    # Copy/Paste/Modify from MetaCommentPlugin
    # SMELL: this is not reliable as it depends on plugin order
    # if (Foswiki::Func::getContext()->{SolrPluginEnabled}) {
    if ($Foswiki::cfg{Plugins}{SolrPlugin}{Enabled}) {
      require Foswiki::Plugins::SolrPlugin;
      Foswiki::Plugins::SolrPlugin::registerIndexAttachmentHandler(
        \&indexAttachmentHandler
      );
    }

    # Plugin correctly initialized
    return 1;
}

sub _restHashify {
    my ($session, $plugin, $verb, $response) = @_;
    return 'You need to be an admin' unless Foswiki::Func::isAnAdmin();

    my $report = '';

    my $query = Foswiki::Func::getCgiQuery();

    my $dryrun = $query->param( 'dryrun' );
    $report .= "Doing dryrun\n<br />\n" if $dryrun;

    my $rehash = $query->param( 'rehash' );
    $report .= "Checking all hashes\n<br />\n" if $rehash;

    my $web = $query->param( 'web' );
    if ( $web ) {
        $web = (Foswiki::Func::normalizeWebTopicName( $web, 'WebHome' ))[0];
        if ( Foswiki::Func::webExists( $web ) ) {
            $report .= _hashify( $web, $rehash, $dryrun );
        } else {
            $report .= "Web does not exist: $web";
        }
    } else {
        foreach my $eachWeb (Foswiki::Func::getListOfWebs('user')) {
            next if ( $eachWeb =~ m#/# ); # skip subwebs, they will be dealt with recursively
            $report .= _hashify( $eachWeb, $rehash, $dryrun );
        }
    }
    return $report;
}

sub _hashify {
    my ( $web, $rehash, $dryrun ) = @_;

    my ( $skipWebs ) = $Foswiki::cfg{Plugins}{DublicatesPlugin}{SkipWebs} || '^(System|Trash)$';
    return "skipping $web\n<br/>\n" if $web =~ m/$skipWebs/;

    my $report = "examining $web\n<br>\n";

    my @topics = Foswiki::Func::getTopicList( $web );
    foreach my $topic ( @topics ) {
        my ( $meta, $text ) = Foswiki::Func::readTopic( $web, $topic );
        my @attachments = $meta->find( 'FILEATTACHMENT' );
        my $changed = 0;
        foreach my $attachment ( @attachments ) {
            my $oldhash = $attachment->{sha1};
            next if $oldhash and not $rehash;

            my $name = $attachment->{name};
            my $file = Foswiki::Func::readAttachment( $web, $topic, $name );
            my $sha1 = Digest::SHA1->new;
            $sha1->add($file);
            my $hash = $sha1->hexdigest;
            next if $oldhash and $oldhash eq $hash;
            $attachment->{sha1} = $hash;
            $changed = 1;
            $report .= "$web.$topic $name got hash: $hash\n<br>\n";
        }
        Foswiki::Func::saveTopic( $web, $topic, $meta, $text, { minor => 1, dontlog => 1 } ) if $changed and not $dryrun;
    }

    my @webs = Foswiki::Func::getListOfWebs( 'user', $web );
    foreach my $eachWeb ( @webs ) {
        $report .= _hashify( $eachWeb );
    }

    return $report;
}

sub beforeUploadHandler {
    my( $attrHashRef, $topic, $web ) = @_;

    my $file = $attrHashRef->{stream};

    my $sha1 = Digest::SHA1->new;

    $sha1->addfile($file);

    my $hash = $sha1->hexdigest;
    $attrHashRef->{sha1} = $hash;
}

sub indexAttachmentHandler {
    my ($indexer, $doc, $web, $topic, $attachment) = @_;

    if($attachment->{sha1}) {
        $doc->add_fields( attachment_sha1_s => $attachment->{sha1} );
    }
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Copyright (C) 2008-2013 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
