# -*- perl -*-
# Lintian::Collect::Source -- interface to source package data collection

# Copyright (C) 2008 Russ Allbery
# Copyright (C) 2009 Raphael Geissert
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation; either version 2 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <http://www.gnu.org/licenses/>.

package Lintian::Collect::Source;

use strict;
use warnings;
use parent 'Lintian::Collect::Package';

use Carp qw(croak);
use Cwd();
use Scalar::Util qw(blessed);

use Lintian::Relation;
use Parse::DebianChangelog;

use Lintian::Util qw(read_dpkg_control $PKGNAME_REGEX);

=head1 NAME

Lintian::Collect::Source - Lintian interface to source package data collection

=head1 SYNOPSIS

    my ($name, $type, $dir) = ('foobar', 'source', '/path/to/lab-entry');
    my $collect = Lintian::Collect->new ($name, $type, $dir);
    if ($collect->native) {
        print "Package is native\n";
    }

=head1 DESCRIPTION

Lintian::Collect::Source provides an interface to package data for source
packages.  It implements data collection methods specific to source
packages.

This module is in its infancy.  Most of Lintian still reads all data from
files in the laboratory whenever that data is needed and generates that
data via collect scripts.  The goal is to eventually access all data about
source packages via this module so that the module can cache data where
appropriate and possibly retire collect scripts in favor of caching that
data in memory.

=head1 CLASS METHODS

=over 4

=item new (PACKAGE)

Creates a new Lintian::Collect::Source object.  Currently, PACKAGE is
ignored.  Normally, this method should not be called directly, only via
the Lintian::Collect constructor.

=cut

# Initialize a new source package collect object.  Takes the package name,
# which is currently unused.
sub new {
    my ($class, $pkg) = @_;
    my $self = {};
    bless($self, $class);
    return $self;
}

=back

=head1 INSTANCE METHODS

In addition to the instance methods listed below, all instance methods
documented in the L<Lintian::Collect> and L<Lintian::Collect::Package>
modules are also available.

=over 4

=item changelog

Returns the changelog of the source package as a Parse::DebianChangelog
object, or C<undef> if the changelog is a symlink or doesn't exist.  The
debfiles collection script must have been run to create the changelog
file, which this method expects to find in F<debfiles/changelog>.

Needs-Info requirements for using I<changelog>: L<Same as debfiles|/debfiles ([FILE])>

=cut

sub changelog {
    my ($self) = @_;
    return $self->{changelog} if exists $self->{changelog};
    my $dch = $self->debfiles('changelog');
    if (-l $dch || !-f $dch) {
        $self->{changelog} = undef;
    } else {
        my %opts = (infile => $dch, quiet => 1);
        $self->{changelog} = Parse::DebianChangelog->init(\%opts);
    }
    return $self->{changelog};
}

=item diffstat

Returns the path to diffstat output run on the Debian packaging diff
(a.k.a. the "diff.gz") for 1.0 non-native packages.  For source
packages without a "diff.gz" component, this returns the path to an
empty file (this may be a device like /dev/null).

Needs-Info requirements for using I<diffstat>: diffstat

=cut

sub diffstat {
    my ($self) = @_;
    return $self->{diffstat} if exists $self->{diffstat};
    my $dstat = $self->lab_data_path('diffstat');
    $dstat = '/dev/null' unless -e $dstat;
    $self->{diffstat} = $dstat;
    return $dstat;
}

=item native

Returns true if the source package is native and false otherwise.
This is generally determined from the source format, though in the 1.0
case the nativeness is determined by looking for the diff.gz (using
the name of the source package and its version).

If the source format is 1.0 and the version number is absent, this
will return false (as native packages are a lot rarer than non-native
ones).

Note if the source format is missing, it is assumed to be an 1.0
package.

Needs-Info requirements for using I<native>: L<Same as field|Lintian::Collect/field ([FIELD[, DEFAULT]])>

=cut

sub native {
    my ($self) = @_;
    return $self->{native} if exists $self->{native};
    my $format = $self->field('format');
    $format = '1.0' unless defined $format;
    if ($format =~ m/^\s*2\.0\s*$/o or $format =~ m/^\s*3\.0\s+\(quilt\)\s*$/o)
    {
        $self->{native} = 0;
    } elsif ($format =~ m/^\s*3\.0\s+\(native\)\s*$/o) {
        $self->{native} = 1;
    } else {
        my $version = $self->field('version');
        my $base_dir = $self->base_dir();
        if (defined $version) {
            $version =~ s/^\d+://;
            my $name = $self->{name};
            $self->{native}
              = (-f "$base_dir/${name}_${version}.diff.gz" ? 0 : 1);
        } else {
            # We do not know, but assume it to non-native as it is
            # the most likely case.
            $self->{native} = 0;
        }
    }
    return $self->{native};
}

=item binaries

Returns a list of the binary and udeb packages listed in the
F<debian/control>.  Package names appear the same order in the
returned list as they do in the control file.

I<Note>: Package names that are not valid are silently ignored.

Needs-Info requirements for using I<binaries>: L<Same as binary_package_type|/binary_package_type (BINARY)>

=cut

sub binaries {
    my ($self) = @_;
    # binary_package_type does all the work for us.
    $self->_load_dctrl unless exists $self->{binary_names};
    return @{ $self->{binary_names} };
}

=item binary_package_type (BINARY)

Returns package type based on value of the Package-Type (or if absent,
X-Package-Type) field.  If the field is omitted, the default value
"deb" is used.

If the BINARY is not a binary listed in the source packages
F<debian/control> file, this method return C<undef>.

Needs-Info requirements for using I<binary_package_type>: L<Same as binary_field|/binary_field (PACKAGE[, FIELD[, DEFAULT]])>

=cut

sub binary_package_type {
    my ($self, $binary) = @_;
    if (exists $self->{binaries}) {
        return $self->{binaries}->{$binary}
          if exists $self->{binaries}->{$binary};
        return;
    }
    # we need the binary fields for this.
    $self->_load_dctrl unless exists $self->{binary_field};

    my %binaries;
    foreach my $pkg (keys %{ $self->{binary_field} }) {
        my $type = $self->binary_field($pkg, 'package-type');
        $type ||= $self->binary_field($pkg, 'xc-package-type') || 'deb';
        $binaries{$pkg} = lc $type;
    }

    $self->{binaries} = \%binaries;
    return $binaries{$binary} if exists $binaries{$binary};
    return;
}

=item source_field([FIELD[, DEFAULT]])

Returns the content of the field FIELD from source package paragraph
of the F<debian/control> file, or DEFAULT (defaulting to C<undef>) if
the field is not present.  Only the literal value of the field is
returned.

If FIELD is not given, return a hashref mapping field names to their
values (in this case DEFAULT is ignored).  This hashref should not be
modified.

The debfiles collection script must have been run to make the
F<debfiles/control> file available.

NB: If a field from the "dsc" file itself is desired, please use
L<field|Lintian::Collect/field> instead.

Needs-Info requirements for using I<source_field>: L<Same as debfiles|/debfiles ([FILE])>

=cut

# NB: We don't say "same as _load_ctrl" in the above, because
# _load_ctrl has no POD and would not appear in the generated
# API-docs.
sub source_field {
    my ($self, $field, $def) = @_;
    $self->_load_dctrl unless exists $self->{source_field};
    return $self->{source_field}{$field}//$def if $field;
    return $self->{source_field};
}

=item orig_index (FILE)

Like L</index> except orig_index is based on the "orig tarballs" of
the source packages.

For native packages L</index> and L</orig_index> are generally
identical.

NB: If sorted_index includes a debian packaging, it is was
contained in upstream part of the source package (or the package is
native).

Needs-Info requirements for using I<orig_index>: src-orig-index

=cut

sub orig_index {
    my ($self, $file) = @_;
    return $self->_fetch_index_data('orig-index', 'src-orig-index', undef,
        $file);
}

=item sorted_orig_index

Like L<sorted_index|Lintian::Collect/sorted_index> except
sorted_orig_index is based on the "orig tarballs" of the source
packages.

For native packages L<sorted_index|Lintian::Collect/sorted_index> and
L</sorted_orig_index> are generally identical.

NB: If sorted_orig_index includes a debian packaging, it is was
contained in upstream part of the source package (or the package is
native).

Needs-Info requirements for using I<sorted_orig_index>: L<Same as orig_index|/orig_index ([FILE])>

=cut

sub sorted_orig_index {
    my ($self) = @_;
    # orig_index does all our work for us, so call it if
    # sorted_orig_index has not been created yet.
    $self->orig_index('') unless exists $self->{'sorted_orig-index'};
    return @{ $self->{'sorted_orig-index'} };
}

=item binary_field (PACKAGE[, FIELD[, DEFAULT]])

Returns the content of the field FIELD for the binary package PACKAGE
in the F<debian/control> file, or DEFAULT (defaulting to C<undef>) if
the field is not present.  Inheritance of field values from the source
section of the control file is not implemented.  Only the literal
value of the field is returned.

If FIELD is not given, return a hashref mapping field names to their
values (in this case, DEFAULT is ignored).  This hashref should not be
modified.

If PACKAGE is not a binary built from this source, this returns
C<undef> regardless of FIELD and DEFAULT.

The debfiles collection script must have been run to make the
F<debfiles/control> file available.

Needs-Info requirements for using I<binary_field>: L<Same as debfiles|/debfiles ([FILE])>

=cut

# NB: We don't say "same as _load_ctrl" in the above, because
# _load_ctrl has no POD and would not appear in the generated
# API-docs.
sub binary_field {
    my ($self, $package, $field, $def) = @_;
    $self->_load_dctrl unless exists $self->{binary_field};

    # Check if the package actually exists, otherwise it may create an
    # empty entry for it.
    if (exists $self->{binary_field}{$package}) {
        return $self->{binary_field}{$package}{$field}//$def if $field;
        return $self->{binary_field}{$package};
    }
    return;
}

# Internal method to load binary and source fields from
# debfiles/control
# sub _load_dctrl Needs-Info debfiles
sub _load_dctrl {
    my ($self) = @_;
    # Load the fields from d/control
    my $dctrl = $self->debfiles('control');
    my $ok = 0;
    if (-l $dctrl) {
        # hmmm - this smells of trouble...
        if (-e $dctrl) {
            # it exists, but what does it point to?
            my $droot = Cwd::abs_path($self->debfiles);
            my $target = Cwd::abs_path($dctrl);
            if ($droot && $target && $target =~ m,^$droot/,) {
                # does not escape $droot, so it could work.
                $ok = 1;
            }
        }
    } else {
        $ok = 1 if -e $dctrl;
    }

    $self->{binary_names} = [];
    unless ($ok) {
        # Bad file, assume the package and field does not exist.
        $self->{binary_field} = {};
        $self->{source_field} = {};
        return;
    }
    my @control_data;
    my %packages;

    eval {@control_data = read_dpkg_control($dctrl);};
    if ($@) {
        # If it is a syntax error, ignore it (we emit
        # syntax-error-in-control-file in this case via
        # control-file).
        die $@ unless $@ =~ /syntax error/;
        $self->{source_field} = {};
        $self->{binary_field} = {};
        return 0;
    }
    my $src = shift @control_data;
    # In theory you can craft a package such that d/control is empty.
    $self->{source_field} = $src // {};

    foreach my $binary (@control_data) {
        my $pkg = $binary->{'package'};
        next unless defined($pkg) and $pkg =~ m{\A $PKGNAME_REGEX \Z}xsmo;
        $packages{$pkg} = $binary;
        push(@{$self->{binary_names} }, $pkg);
    }
    $self->{binary_field} = \%packages;

    return 1;
}

=item binary_relation (PACKAGE, FIELD)

Returns a L<Lintian::Relation> object for the specified FIELD in the
binary package PACKAGE in the F<debian/control> file.  FIELD should be
one of the possible relationship fields of a Debian package or one of
the following special values:

=over 4

=item all

The concatenation of Pre-Depends, Depends, Recommends, and Suggests.

=item strong

The concatenation of Pre-Depends and Depends.

=item weak

The concatenation of Recommends and Suggests.

=back

If FIELD isn't present in the package, the returned Lintian::Relation
object will be empty (always satisfied and implies nothing).

Any substvars in F<debian/control> will be represented in the returned
relation as packages named after the substvar.

Needs-Info requirements for using I<binary_relation>: L<Same as binary_field|/binary_field (PACKAGE[, FIELD[, DEFAULT]])>

=cut

sub binary_relation {
    my ($self, $package, $field) = @_;
    $field = lc $field;
    return $self->{binary_relation}->{$package}->{$field}
      if exists $self->{binary_relation}->{$package}->{$field};

    my %special = (
        all    => [qw(pre-depends depends recommends suggests)],
        strong => [qw(pre-depends depends)],
        weak   => [qw(recommends suggests)]);
    my $result;
    if ($special{$field}) {
        $result
          = Lintian::Relation->and(map { $self->binary_relation($package, $_) }
              @{ $special{$field} });
    } else {
        my %known = map { $_ => 1 }
          qw(pre-depends depends recommends suggests enhances breaks
          conflicts provides replaces);
        croak("unknown relation field $field") unless $known{$field};
        my $value = $self->binary_field($package, $field);
        $result = Lintian::Relation->new($value);
    }
    $self->{binary_relation}->{$package}->{$field} = $result;
    return $result;
}

=item relation (FIELD)

Returns a L<Lintian::Relation> object for the given build relationship
field FIELD.  In addition to the normal build relationship fields, the
following special field names are supported:

=over 4

=item build-depends-all

The concatenation of Build-Depends, Build-Depends-Arch and
Build-Depends-Indep.

=item build-conflicts-all

The concatenation of Build-Conflicts, Build-Conflicts-Arch and
Build-Conflicts-Indep.

=back

If FIELD isn't present in the package, the returned Lintian::Relation
object will be empty (always satisfied and implies nothing).

Needs-Info requirements for using I<relation>: L<Same as field|Lintian::Collect/field ([FIELD[, DEFAULT]])>

=cut

sub relation {
    my ($self, $field) = @_;
    $field = lc $field;
    return $self->{relation}->{$field} if exists $self->{relation}->{$field};

    my $result;
    if ($field =~ /^build-(depends|conflicts)-all$/) {
        my $type = $1;
        my @fields = ("build-$type", "build-$type-indep", "build-$type-arch");
        $result = Lintian::Relation->and(map { $self->relation($_) } @fields);
    } elsif ($field =~ /^build-(depends|conflicts)(?:-(?:arch|indep))?$/) {
        my $value = $self->field($field);
        $result = Lintian::Relation->new($value);
    } else {
        croak("unknown relation field $field");
    }
    $self->{relation}{$field} = $result;
    return $result;
}

=item relation_noarch (FIELD)

The same as L</relation (FIELD)>, but ignores architecture
restrictions in the FIELD field.

Needs-Info requirements for using I<relation_noarch>: L<Same as field|Lintian::Collect/field ([FIELD[, DEFAULT]])>

=cut

sub relation_noarch {
    my ($self, $field) = @_;
    $field = lc $field;
    return $self->{relation_noarch}->{$field}
      if exists $self->{relation_noarch}->{$field};

    my $result;
    if ($field =~ /^build-(depends|conflicts)-all$/) {
        my $type = $1;
        my @fields = ("build-$type", "build-$type-indep", "build-$type-arch");
        $result
          = Lintian::Relation->and(map { $self->relation_noarch($_) } @fields);
    } elsif ($field =~ /^build-(depends|conflicts)(?:-(?:arch|indep))?$/) {
        my $value = $self->field($field);
        $result = Lintian::Relation->new_noarch($value);
    } else {
        croak("unknown relation field $field");
    }
    $self->{relation_noarch}{$field} = $result;
    return $result;
}

=item debfiles ([FILE])

Returns the path to FILE in the debian dir of the extracted source
package.  FILE must be relative to the root of the debian dir and
should be without leading slash (and and without "./").  If FILE is
not in the debian dir, it returns the path to a non-existent file
entry.

It is not permitted for FILE to be C<undef>.  If the "root" dir is
desired either invoke this method without any arguments at all or use
the empty string.

The caveats of L<unpacked|Lintian::Collect::Package/unpacked ([FILE])>
also apply to this method.

Needs-Info requirements for using I<debfiles>: debfiles

=cut

sub debfiles {
    ## no critic (Subroutines::RequireArgUnpacking)
    # - see L::Collect::unpacked for why
    my $self = shift(@_);
    if (defined($_[0]) && blessed($_[0])) {
        croak('debfiles does not accept blessed objects');
    }
    return $self->_fetch_extracted_dir('debfiles', 'debfiles', @_);
}

=item index (FILE)

For the general documentation of this method, please refer to the
documentation of it in
L<Lintian::Collect::Package|Lintian::Collect::Package/index (FILE)>.

The index of a source package is not very well defined for non-native
source packages.  This method gives the index of the "unpacked"
package (with 3.0 (quilt), this implies patches have been applied).

If you want the index of what is listed in the upstream orig tarballs,
then there is L</orig_index>.

For native packages, the two indices are generally the same as they
only have one tarball and their debian packaging is included in that
tarball.

IMPLEMENTATION DETAIL/CAVEAT: Lintian currently (2.5.11) generates
this by running "find(1)" after unpacking the the source package.
This has three consequences.

First it means that (original) owner/group data is lost; Lintian
inserts "root/root" here.  This is usually not a problem as
owner/group information for source packages do not really follow any
standards.

Secondly, permissions are modified by A) umask and B) laboratory
set{g,u}id bits (the laboratory on lintian.d.o has setgid).  This is
*not* corrected/altered.  Note Lintian (usually) breaks if any of the
"user" bits are set in the umask, so that part of the permission bit
I<should> be reliable.

Again, this shouldn't be a problem as permissions in source packages
are usually not important.  Though if accuracy is needed here,
L</orig_index> may used instead (assuming it has the file in
question).

Third, hardlinking information is lost and no attempt has been made
to restore it.

Needs-Info requirements for using I<index>: unpacked

=cut

sub index {
    my ($self, $file) = @_;
    return $self->_fetch_index_data('index', 'index', undef, $file);
}

=item is_non_free

Returns a truth value if the package appears to be non-free (based on
the section field; "non-free/*" and "restricted/*")

Needs-Info requirements for using I<is_non_free>: L</source_field ([FIELD[, DEFAULT]])>

=cut

sub is_non_free {
    my ($self) = @_;
    return $self->{is_non_free} if exists $self->{is_non_free};
    $self->{is_non_free} = 0;
    $self->{is_non_free} = 1
      if $self->source_field('section', 'main')
      =~ m,^(?:non-free|restricted|multiverse)/,;
    return $self->{is_non_free};
}

=back

=head1 AUTHOR

Originally written by Russ Allbery <rra@debian.org> for Lintian.

=head1 SEE ALSO

lintian(1), Lintian::Collect(3), Lintian::Relation(3)

=cut

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
