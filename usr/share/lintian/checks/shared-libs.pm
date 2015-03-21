# shared-libs -- lintian check script -*- perl -*-

# Copyright (C) 1998 Christian Schwarz
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, you can find it on the World Wide
# Web at http://www.gnu.org/copyleft/gpl.html, or write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA 02110-1301, USA.

package Lintian::shared_libs;
use strict;
use warnings;
use autodie;

use File::Basename;
use List::MoreUtils qw(any none);

use Lintian::Data;
use Lintian::Relation;
use Lintian::Tags qw(tag);
use Lintian::Util qw(fail normalize_pkg_path slurp_entire_file);

# Libraries that should only be used in the presence of certain capabilities
# may be located in subdirectories of the standard ldconfig search path with
# one of the following names.
my $HWCAP_DIRS = Lintian::Data->new('shared-libs/hwcap-dirs');

# The following architectures should always have a STACK setting in shared
# libraries to disable executable stack.  Other architectures don't always add
# this section and therefore can't be checked.
my %stack_arches = map { $_ => 1 }qw(
  alpha
  amd64
  i386
  m68k
  powerpc
  s390
  sparc
);

my $ldconfig_dirs = Lintian::Data->new('shared-libs/ldconfig-dirs');
my $MA_DIRS = Lintian::Data->new('common/multiarch-dirs', qr/\s++/);

sub run {
    my ($pkg, $type, $info, $proc, $group) = @_;

    my ($must_call_ldconfig, %SONAME, %sharedobject);
    my @shlibs;
    my @words;
    my @devpkgs;
    my $objdump = $info->objdump_info;

    # 1st step: get info about shared libraries installed by this package
    foreach my $file (sort keys %{$objdump}) {
        $SONAME{$file} = $objdump->{$file}->{SONAME}[0]
          if scalar @{ $objdump->{$file}->{SONAME} };
    }

    foreach my $file ($info->sorted_index) {
        my $fileinfo = $info->file_info($file);
        if ($fileinfo =~ m/^[^,]*\bELF\b/ && $fileinfo =~ m/shared object/) {
            $sharedobject{$file} = 1;
        }
    }

    if (%SONAME) {
        foreach my $bin ($group->get_binary_processables) {
            next unless $bin->pkg_name =~ m/\-dev$/;
            if ($bin->info->relation('strong')->implies($pkg)) {
                push @devpkgs, $bin;
            }
        }
    }

    # 2nd step: read package contents

    for my $cur_file ($info->sorted_index) {
        # shared library?

        my $normalized_target;
        $normalized_target
          = normalize_pkg_path(join('/', dirname($cur_file), $cur_file->link))
          if defined $cur_file->link;

        if (
            exists $SONAME{$cur_file}
            or (defined $normalized_target
                and exists $SONAME{$normalized_target})
          ) {
            # yes!!
            my ($real_file, $perm);
            if (exists $SONAME{$cur_file}) {
                $real_file = $cur_file;
                $perm = $cur_file->operm;
            } else {
                $real_file = $normalized_target;
                # perm not needed for this branch
            }

            # Installed in a directory controlled by the dynamic
            # linker?  We have to strip off directories named for
            # hardware capabilities.
            if (needs_ldconfig($cur_file)) {
                # yes! so postinst must call ldconfig
                $must_call_ldconfig = $real_file;
            }
            # At this point, we do not want to process symlinks as
            # they will only lead to duplicate warnings.
            next unless $cur_file eq $real_file;

            # Now that we're sure this is really a shared library, report on
            # non-PIC problems.
            if ($objdump->{$cur_file}->{TEXTREL}) {
                tag 'shlib-with-non-pic-code', $cur_file;
            }

            my @symbol_names
              = map { @{$_}[2] } @{$objdump->{$cur_file}->{SYMBOLS}};
            if (   (any { m/^_?exit$/ } @symbol_names)
                && (none { $_ eq 'fork' } @symbol_names)) {
                # If it has an INTERP section it might be an application with
                # a SONAME (hi openjdk-6, see #614305).  Also see the comment
                # for "shlib-with-executable-bit" below.
                tag 'shlib-calls-exit', $cur_file
                  unless $objdump->{$cur_file}->{INTERP};
            }

            # executable?
            my $perms = sprintf('%04o', $perm);
            if ($perm & 0111) {
                # Yes.  But if the library has an INTERP section, it's
                # designed to do something useful when executed, so don't
                # report an error.  Also give ld.so a pass, since it's
                # special.
                tag 'shlib-with-executable-bit', $cur_file, $perms
                  unless ($objdump->{$cur_file}->{INTERP}
                    or $cur_file =~ m,^lib(?:32|64)?/ld-[\d.]+\.so$,);
            } elsif ($perm != 0644) {
                tag 'shlib-with-bad-permissions', $cur_file, $perms;
            }

            # executable stack.  We can only warn about a missing
            # section on some architectures.  Only warn if there's an
            # Architecture field; if that's missing, we'll already be
            # complaining elsewhere.
            if (not defined $objdump->{$cur_file}->{'PH'}->{STACK}) {
                if (defined $info->field('architecture')) {
                    my $arch = $info->field('architecture');
                    tag 'shlib-without-PT_GNU_STACK-section', $cur_file
                      if $stack_arches{$arch};
                }
            } elsif ($objdump->{$cur_file}->{'PH'}->{STACK}->{flags} ne 'rw-'){
                tag 'shlib-with-executable-stack', $cur_file;
            }
        } elsif ($ldconfig_dirs->known(dirname($cur_file))
            && exists $sharedobject{$cur_file}) {
            tag 'sharedobject-in-library-directory-missing-soname', $cur_file;
        } elsif ($cur_file =~ m/\.la$/ and not defined $cur_file->link) {
            local $_;
            open(my $fd, '<', $info->unpacked($cur_file));
            while(<$fd>) {
                next
                  unless (m/^(libdir)='(.+?)'$/)
                  or (m/^(dependency_libs)='(.+?)'$/);
                my ($field, $value) = ($1, $2);
                if ($field eq 'libdir') {
                    # dirname with leading slash and without the trailing one.
                    my $expected = '/' . substr($cur_file->dirname, 0, -1);
                    $value =~ s,/+$,,;

                    # python-central is a special case since the
                    # libraries are moved at install time.
                    next
                      if ($value
                        =~ m,^/usr/lib/python[\d.]+/(?:site|dist)-packages,
                        and $expected =~ m,^/usr/share/pyshared,);
                    tag 'incorrect-libdir-in-la-file', $cur_file,
                      "$value != $expected"
                      unless($expected eq $value);
                } elsif ($field eq 'dependency_libs'){
                    tag 'non-empty-dependency_libs-in-la-file', $cur_file;
                }
            }
            close($fd);
        }
    }

    # 3rd step: check if shlib symlinks are present and in correct order
    for my $shlib_file (keys %SONAME) {
        # file found?
        if (not $info->index($shlib_file)) {
            fail(
                "shlib $shlib_file not found in package (should not happen!)");
        }

        my ($dir, $shlib_name) = $shlib_file =~ m,(.*)/([^/]+)$,;

        # not a public shared library, skip it
        next unless $ldconfig_dirs->known($dir);

        # symlink found?
        my $link_file = "$dir/$SONAME{$shlib_file}";
        if (not $info->index($link_file)) {
            tag 'ldconfig-symlink-missing-for-shlib',
              "$link_file $shlib_file $SONAME{$shlib_file}";
        } else {
            # $link_file really another file?
            if ($link_file eq $shlib_file) {
                # the library file uses its SONAME, this is ok...
            } else {
                # $link_file really a symlink?
                if ($info->index($link_file)->is_symlink) {
                    # yes.

                    # $link_file pointing to correct file?
                    if ($info->index($link_file)->link eq $shlib_name) {
                        # ok.
                    } else {
                        tag 'ldconfig-symlink-referencing-wrong-file',
                          join(q{ },
                            "$link_file ->",
                            $info->index($link_file)->link,
                            "instead of $shlib_name");
                    }
                } else {
                    tag 'ldconfig-symlink-is-not-a-symlink',
                      "$shlib_file $link_file";
                }
            }
        }

        # libtool "-release" variant
        $link_file =~ s/-[\d\.]+\.so$/.so/o;
        # determine shlib link name (w/o version)
        $link_file =~ s/\.so.+$/.so/o;

        # shlib symlink may not exist.
        # if shlib doesn't _have_ a version, then $link_file and
        # $shlib_file will be equal, and it's not a development link,
        # so don't complain.
        if ($info->index($link_file) and $link_file ne $shlib_file) {
            tag 'non-dev-pkg-with-shlib-symlink', "$shlib_file $link_file";
        } elsif (@devpkgs) {
            # -dev package - it needs a shlib symlink
            my $ok = 0;
            my @alt;

            # If the shared library is in /lib, we have to look for
            # the dev symlink in /usr/lib
            $link_file = "usr/$link_file" unless $shlib_file =~ m,^usr/,;

            push @alt, $link_file;

            if ($proc->pkg_src =~ m/^gcc-(\d+.\d+)$/o) {
                # gcc has a lot of bi-arch libs and puts the dev symlink
                # in slightly different directories (to be co-installable
                # with itself I guess).  Allegedly, clang (etc.) have to
                # handle these special cases, so it should be
                # acceptable...
                my $gcc_ver = $1;
                my $basename = basename($link_file);
                my $madir = $MA_DIRS->value($proc->pkg_arch);
                my $stem;
                # Generally we are looking for
                #  * usr/lib/gcc/MA-TRIPLET/$gcc_ver/${BIARCH}$basename
                #
                # Where BIARCH is one of {,32/,n32/,x32/,sf/,hf/}.  Note
                # the "empty string" as a possible option.
                #
                # The two-three letter name directory before the
                # basename is bi-arch names.
                $stem = "usr/lib/gcc/$madir/$gcc_ver" if defined $madir;
                # But in the rare case we don't know the Multi-arch dir,
                # just do without it as often (but not always) works.
                $stem = "usr/lib/gcc/$gcc_ver" unless defined $madir;

                push @alt, map { "$stem/$_"  } ('', qw(32 n32 x32 sf hf));
            }

          PKG:
            foreach my $devpkg (@devpkgs) {
                my $dinfo = $devpkg->info;
                foreach my $link (@alt) {
                    if ($devpkg->info->index($link)) {
                        $ok = 1;
                        last PKG;
                    }
                }
            }
            tag 'dev-pkg-without-shlib-symlink', "$shlib_file $link_file"
              unless $ok;
        }
    }

    # 4th step: check shlibs control file
    # $version may be undef in very broken packages
    my $version = $info->field('version');
    my $provides = $pkg;
    $provides .= "( = $version)" if defined $version;
    # Assume the version to be a non-native version to avoid
    # uninitialization warnings later.
    $version = '0-1' unless defined $version;
    $provides = Lintian::Relation->and($info->relation('provides'), $provides);

    my $shlibsf = $info->control('shlibs');
    my $symbolsf = $info->control('symbols');
    my (%shlibs_control, %symbols_control);

    # Libraries with no version information can't be represented by
    # the shlibs format (but can be represented by symbols).  We want
    # to warn about them if they appear in public directories.  If
    # they're in private directories, assume they're plugins or
    # private libraries and are safe.
    my %unversioned_shlibs;
    for (keys %SONAME) {
        my $soname = format_soname($SONAME{$_});
        if ($soname !~ / /) {
            $unversioned_shlibs{$_} = 1;
            tag 'shlib-without-versioned-soname', $_, $soname
              if $ldconfig_dirs->known(dirname($_));
        }
    }
    @shlibs = grep { !$unversioned_shlibs{$_} } keys %SONAME;

    if (-l $shlibsf) {
        # control files are not symlinks, skip this part.
    } elsif ($#shlibs == -1) {
        # no shared libraries included in package, thus shlibs control
        # file should not be present
        if (-f $shlibsf) {
            tag 'pkg-has-shlibs-control-file-but-no-actual-shared-libs';
        }
    } else {
        # shared libraries included, thus shlibs control file has to exist
        if (not -f $shlibsf) {
            if ($type ne 'udeb') {
                for my $shlib (@shlibs) {
                    # skip it if it's not a public shared library
                    next unless $ldconfig_dirs->known(dirname($shlib));
                    tag 'no-shlibs-control-file', $shlib
                      unless is_nss_plugin($shlib);
                }
            }
        } else {
            my (%shlibs_control_used, @shlibs_depends);
            open(my $fd, '<', $shlibsf);
            while (<$fd>) {
                chop;
                next if m/^\s*$/ or /^#/;

                # We exclude udebs from the checks for correct shared library
                # dependencies, since packages may contain dependencies on
                # other udeb packages.
                my $udeb = '';
                $udeb = 'udeb: ' if s/^udeb:\s+//o;
                @words = split(/\s+/o,$_);
                my $shlibs_string = $udeb.$words[0].' '.$words[1];
                if ($shlibs_control{$shlibs_string}) {
                    tag 'duplicate-entry-in-shlibs-control-file',
                      $shlibs_string;
                } else {
                    $shlibs_control{$shlibs_string} = 1;
                    push(@shlibs_depends, join(' ', @words[2 .. $#words]))
                      unless $udeb;
                }
            }
            close($fd);
            for my $shlib (@shlibs) {
                my $shlib_name = $SONAME{$shlib};
                $shlib_name = format_soname($shlib_name);
                $shlibs_control_used{$shlib_name} = 1;
                $shlibs_control_used{'udeb: '.$shlib_name} = 1;
                unless (exists $shlibs_control{$shlib_name}) {
                    # skip it if it's not a public shared library
                    next unless $ldconfig_dirs->known(dirname($shlib));
                    # no!!
                    tag 'shlib-missing-in-control-file', $shlib_name, 'for',
                      $shlib
                      unless is_nss_plugin($shlib);
                }
            }
            for my $shlib_name (keys %shlibs_control) {
                tag 'unused-shlib-entry-in-control-file', $shlib_name
                  unless $shlibs_control_used{$shlib_name};
            }

            # Check that all of the packages listed as dependencies in
            # the shlibs file are satisfied by the current package or
            # its Provides.  Normally, packages should only declare
            # dependencies in their shlibs that they themselves can
            # satisfy.
            #
            # Deduplicate the list of dependencies before warning so
            # that we don't dupliate warnings.
            my %seen;
            @shlibs_depends = grep { !$seen{$_}++ } @shlibs_depends;
            for my $depend (@shlibs_depends) {
                unless ($provides->implies($depend)) {
                    tag 'shlibs-declares-dependency-on-other-package', $depend;
                }
                tag 'shlibs-uses-obsolete-relation', $depend
                  if $depend =~ m/\(\s*[><](?![<>=])\s*/;
            }
        }
    }

    # 5th step: check symbols control file.  Add back in the unversioned shared
    # libraries, since they can still have symbols files.
    if (-l $symbolsf) {
        # control files are not symlinks, skip this part.
    } elsif ($#shlibs == -1 and not %unversioned_shlibs) {
        # no shared libraries included in package, thus symbols
        # control file should not be present
        if (-f $symbolsf) {
            tag 'pkg-has-symbols-control-file-but-no-shared-libs';
        }
    } elsif (not -f $symbolsf) {
        if ($type ne 'udeb') {
            for my $shlib (@shlibs, keys %unversioned_shlibs) {
                # skip it if it's not a public shared library
                next unless $ldconfig_dirs->known(dirname($shlib));
                tag 'no-symbols-control-file', $shlib
                  unless is_nss_plugin($shlib);
            }
        }
    } elsif (-f $symbolsf) {
        my $version_wo_rev = $version;
        $version_wo_rev =~ s/^(.+)-([^-]+)$/$1/;
        my ($full_version_count, $full_version_sym) = (0, undef);
        my ($debian_revision_count, $debian_revision_sym) = (0, undef);
        my ($soname, $dep_package, $dep);
        my %symbols_control_used;
        my @symbols_depends;
        my $dep_templates = 0;
        my $meta_info_seen = 0;
        my $warned = 0;
        my $symbol_count = 0;

        open(my $fd, '<', $symbolsf);
        while (<$fd>) {
            chomp;
            next if m/^\s*$/ or /^#/;

            if (m/^([^\s|*]\S+)\s\S+\s*(?:\(\S+\s+\S+\)|\#MINVER\#)?/) {
                # soname, main dependency template

                $soname = $1;
                s/^\Q$soname\E\s*//;
                $soname = format_soname($soname);

                if ($symbols_control{$soname}) {
                    tag 'duplicate-entry-in-symbols-control-file', $soname;
                } else {
                    $symbols_control{$soname} = 1;
                    $warned = 0;

                    foreach my $part (split /\s*,\s*/) {
                        foreach my $subpart (split /\s*\|\s*/, $part) {
                            $subpart
                              =~ m,^(\S+)(\s*(?:\(\S+\s+\S+\)|#MINVER#))?$,;
                            ($dep_package, $dep) = ($1, $2 || '');
                            if (defined $dep_package) {
                                push @symbols_depends, $dep_package . $dep;
                            } else {
                                tag 'syntax-error-in-symbols-file', $.
                                  unless $warned;
                                $warned = 1;
                            }
                        }
                    }
                }

                $dep_templates = 0;
                $meta_info_seen = 0;
                $symbol_count = 0;
            } elsif (m/^\|\s+\S+\s*(?:\(\S+\s+\S+\)|#MINVER#)?/) {
                # alternative dependency template

                $warned = 0;

                if ($meta_info_seen or not defined $soname) {
                    tag 'syntax-error-in-symbols-file', $.;
                    $warned = 1;
                }

                s/^\|\s*//;

                foreach my $part (split /\s*,\s*/) {
                    foreach my $subpart (split /\s*\|\s*/, $part) {
                        $subpart =~ m,^(\S+)(\s*(?:\(\S+\s+\S+\)|#MINVER#))?$,;
                        ($dep_package, $dep) = ($1, $2 || '');
                        if (defined $dep_package) {
                            push @symbols_depends, $dep_package . $dep;
                        } else {
                            tag 'syntax-error-in-symbols-file', $.
                              unless $warned;
                            $warned = 1;
                        }
                    }
                }

                $dep_templates++ unless $warned;
            } elsif (m/^\*\s(\S+):\s\S+/) {
                # meta-information

                # This should probably be in a hash, but there's
                # only one supported value currently
                tag 'unknown-meta-field-in-symbols-file', "$1, line $."
                  unless $1 eq 'Build-Depends-Package';
                tag 'syntax-error-in-symbols-file', $.
                  unless defined $soname and $symbol_count == 0;

                $meta_info_seen = 1;
            } elsif (m/^\s+(\S+)\s(\S+)(?:\s(\S+(?:\s\S+)?))?$/) {
                # Symbol definition

                tag 'syntax-error-in-symbols-file', $.
                  unless defined $soname;

                $symbol_count++;
                my ($sym, $v, $dep_order) = ($1, $2, $3);
                $dep_order ||= '';

                if (($v eq $version) and ($version =~ /-/)) {
                    $full_version_sym ||= $sym;
                    $full_version_count++;
                } elsif (($v =~ /-/)
                    and (not $v =~ /~$/)
                    and ($v ne $version_wo_rev)) {
                    $debian_revision_sym ||= $sym;
                    $debian_revision_count++;
                }

                if (length $dep_order) {
                    if ($dep_order !~ /^\d+$/ or $dep_order > $dep_templates) {
                        tag 'invalid-template-id-in-symbols-file', $.;
                    }
                }
            } else {
                # Unparseable line

                tag 'syntax-error-in-symbols-file', $.;
            }
        }
        close($fd);
        if ($full_version_count) {
            $full_version_count--;
            my $others = '';
            if ($full_version_count > 0) {
                $others = " and $full_version_count others";
            }
            tag 'symbols-file-contains-current-version-with-debian-revision',
              "on symbol $full_version_sym$others";
        }
        if ($debian_revision_count) {
            $debian_revision_count--;
            my $others = '';
            if ($debian_revision_count > 0) {
                $others = " and $debian_revision_count others";
            }
            tag 'symbols-file-contains-debian-revision',
              "on symbol $debian_revision_sym$others";
        }
        for my $shlib (@shlibs, keys %unversioned_shlibs) {
            my $shlib_name = $SONAME{$shlib};
            $shlib_name = format_soname($shlib_name);
            $symbols_control_used{$shlib_name} = 1;
            $symbols_control_used{'udeb: '.$shlib_name} = 1;
            unless (exists $symbols_control{$shlib_name}) {
                # skip it if it's not a public shared library
                next unless $ldconfig_dirs->known(dirname($shlib));
                tag 'shlib-missing-in-symbols-control-file', $shlib_name,
                  'for', $shlib
                  unless is_nss_plugin($shlib);
            }
        }
        for my $shlib_name (keys %symbols_control) {
            tag 'unused-shlib-entry-in-symbols-control-file', $shlib_name
              unless $symbols_control_used{$shlib_name};
        }

        # Check that all of the packages listed as dependencies in the symbols
        # file are satisfied by the current package or its Provides.
        # Normally, packages should only declare dependencies in their symbols
        # files that they themselves can satisfy.
        #
        # Deduplicate the list of dependencies before warning so that we don't
        # dupliate warnings.
        my %seen;
        @symbols_depends = grep { !$seen{$_}++ } @symbols_depends;
        for my $depend (@symbols_depends) {
            unless ($provides->implies($depend)) {
                tag 'symbols-declares-dependency-on-other-package', $depend;
            }
        }
    }

    # Compare the contents of the shlibs and symbols control files, but exclude
    # from this check shared libraries whose SONAMEs has no version.  Those can
    # only be represented in symbols files and aren't expected in shlibs files.
    if (keys %shlibs_control and keys %symbols_control) {
        for my $key (keys %symbols_control) {
            unless (exists $shlibs_control{$key} or $key !~ / /) {
                tag 'symbols-declared-but-not-shlib', $key;
            }
        }
    }

    # 6th step: check pre- and post- control files
    if (-f $info->control('preinst') and not -l $info->control('preinst')) {
        local $_ = slurp_entire_file($info->control('preinst'));
        if (/^[^\#]*\bldconfig\b/m) {
            tag 'preinst-calls-ldconfig';
        }
    }

    my $we_call_postinst=0;
    if (-f $info->control('postinst') and not -l $info->control('postinst')) {
        local $_ = slurp_entire_file($info->control('postinst'));

        # Decide if we call ldconfig
        if (/^[^\#]*\bldconfig\b/m) {
            $we_call_postinst=1;
        }
    }

    if ($type eq 'udeb') {
        tag 'udeb-postinst-must-not-call-ldconfig'
          if $we_call_postinst;
    } else {
        tag 'postinst-has-useless-call-to-ldconfig'
          if $we_call_postinst and not $must_call_ldconfig;
        tag 'postinst-must-call-ldconfig', $must_call_ldconfig
          if not $we_call_postinst and $must_call_ldconfig;
    }

    my $multiarch = $info->field('multi-arch') // 'no';
    if ($multiarch eq 'foreign' and $must_call_ldconfig) {
        tag 'shlib-in-multi-arch-foreign-package', $must_call_ldconfig;
    }

    if (-f $info->control('prerm') and not -l $info->control('prerm')) {
        local $_ = slurp_entire_file($info->control('prerm'));
        if (/^[^\#]*\bldconfig\b/m) {
            tag 'prerm-calls-ldconfig';
        }
    }

    if (-f $info->control('postrm') and not -l $info->control('postrm')) {
        local $_ = slurp_entire_file($info->control('postrm'));

        # Decide if we call ldconfig
        if (/^[^\#]*\bldconfig\b/m) {
            tag 'postrm-has-useless-call-to-ldconfig',
              unless $must_call_ldconfig;
        } else {
            tag 'postrm-should-call-ldconfig', $must_call_ldconfig
              if $must_call_ldconfig;
        }

        # Decide if we do it safely
        s/\bldconfig\b/BldconfigB/g;
        s/[ \t]//g;
        # this one matches code from debhelper
        s/^if\["\$1"=.?remove.?\];?\n*then\n*BldconfigB//gm;
        # variations...
        s/^if\[.?remove.?="\$1"\];?\n*then\n*BldconfigB//gm;
        s/^\["\$1"=.?remove.?\]\&&BldconfigB//gm;
        s/^\[.?remove.?="\$1"\]&&BldconfigB//gm;
        s/remove(?:\|[^)]+)*\).*?BldconfigB.*?(?:;;|esac)//s;

        if (/^[^\#]*BldconfigB/m) {
            tag 'postrm-unsafe-ldconfig';
        }
    }

    return;
}

# Extract the library name and the version from an SONAME and return them
# separated by a space.  This code should match the split_soname function in
# dpkg-shlibdeps.
sub format_soname {
    my $soname = shift;

    # libfoo.so.X.X
    if ($soname =~ /^(.*)\.so\.(.*)$/) {
        $soname = "$1 $2";
        # libfoo-X.X.so
    } elsif ($soname =~ /^(.*)-(\d.*)\.so$/) {
        $soname = "$1 $2";
    }

    return $soname;
}

# Returns a truth value if the first argument appears to be the path
# to an libc nss plugin (libnss_<name>.so.$version).
sub is_nss_plugin {
    my ($path) = @_;
    return 1 if $path =~ m,^(.*/)?libnss_[^.]+\.so\.\d+$,o;
    return 0;
}

sub needs_ldconfig {
    my ($file) = @_;
    my $dirname = dirname($file);
    my $last;
    do {
        $dirname =~ s%/([^/]+)$%%;
        $last = $1;
    } while ($last && $HWCAP_DIRS->known($last));
    $dirname .= "/$last" if $last;
    # yes! so postinst must call ldconfig
    return 1 if $ldconfig_dirs->known($dirname);
    return;
}

1;

# Local Variables:
# indent-tabs-mode: nil
# cperl-indent-level: 4
# End:
# vim: syntax=perl sw=4 sts=4 sr et
