#
# debbugs.py - Routines to deal with BTS web pages
#
#   Written by Chris Lawrence <lawrencc@debian.org>
#   (C) 1999-2008 Chris Lawrence
#   Copyright (C) 2008-2019 Sandro Tosi <morph@debian.org>
#
# This program is freely distributable per the following license:
#
#  Permission to use, copy, modify, and distribute this software and its
#  documentation for any purpose and without fee is hereby granted,
#  provided that the above copyright notice appears in all copies and that
#  both that copyright notice and this permission notice appear in
#  supporting documentation.
#
#  I DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING ALL
#  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL I
#  BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY
#  DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
#  WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
#  ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
#  SOFTWARE.

from . import utils
import sys
import mailbox
import email
import email.errors
import io
import glob
import os
import re
import urllib.request, urllib.parse, urllib.error
import textwrap
# SOAP interface to Debian BTS
import debianbts
from collections import defaultdict

from . import checkversions
from .exceptions import (
    NoNetwork,
    QuertBTSError,
)
from .urlutils import open_url


def msgfactory(fp):
    try:
        return email.message_from_file(fp)
    except email.errors.MessageParseError:
        # Don't return None since that will
        # stop the mailbox iterator
        return ''


class Error(Exception):
    pass


# Severity levels
SEVERITIES = {
    'critical': """makes unrelated software on the system (or the
    whole system) break, or causes serious data loss, or introduces a
    security hole on systems where you install the package.""",
    'grave': """makes the package in question unusable by most or all users,
    or causes data loss, or introduces a security hole allowing access
    to the accounts of users who use the package.""",
    'serious': """is a severe violation of Debian policy (that is,
    the problem is a violation of a 'must' or 'required' directive);
    may or may not affect the usability of the package.  Note that non-severe
    policy violations may be 'normal,' 'minor,' or 'wishlist' bugs.
    (Package maintainers may also designate other bugs as 'serious' and thus
    release-critical; however, end users should not do so.). For the canonical
    list of issues deserving a serious severity you can refer to this webpage:
    http://release.debian.org/testing/rc_policy.txt .""",
    'important': """a bug which has a major effect on the usability
    of a package, without rendering it completely unusable to
    everyone.""",
    'does-not-build': """a bug that stops the package from being built
    from source.  (This is a 'virtual severity'.)""",
    'normal': """a bug that does not undermine the usability of the
    whole package; for example, a problem with a particular option or
    menu item.""",
    'minor': """things like spelling mistakes and other minor
    cosmetic errors that do not affect the core functionality of the
    package.""",
    'wishlist': "suggestions and requests for new features.",
}

# justifications for critical bugs
JUSTIFICATIONS = {
    'critical': (
        ('breaks unrelated software', """breaks unrelated software on the system
    (packages that have a dependency relationship are not unrelated)"""),
        ('breaks the whole system', """renders the entire system unusable (e.g.,
    unbootable, unable to reach a multiuser runlevel, etc.)"""),
        ('causes serious data loss', """causes loss of important, irreplaceable
    data"""),
        ('root security hole', """introduces a security hole allowing access to
    root (or another privileged system account), or data normally
    accessible only by such accounts"""),
        ('unknown', """not sure, or none of the above"""),
    ),
    'grave': (
        ('renders package unusable', """renders the package unusable, or mostly
    so, on all or nearly all possible systems on which it could be installed
    (i.e., not a hardware-specific bug); or renders package uninstallable
    or unremovable without special effort"""),
        ('causes non-serious data loss', """causes the loss of data on the system
    that is unimportant, or restorable without resorting to backup media"""),
        ('user security hole', """introduces a security hole allowing access to
    user accounts or data not normally accessible"""),
        ('unknown', """not sure, or none of the above"""),
    )
}


# Ordering for justifications
JUSTORDER = {
    'critical': ['breaks unrelated software',
                 'breaks the whole system',
                 'causes serious data loss',
                 'root security hole',
                 'unknown'],
    'grave': ['renders package unusable',
              'causes non-serious data loss',
              'user security hole',
              'unknown']
}

SEVERITIES_gnats = {
    'critical': 'The product, component or concept is completely'
                'non-operational or some essential functionality is missing.  No'
                'workaround is known.',
    'serious': 'The product, component or concept is not working'
               'properly or significant functionality is missing.  Problems that'
               'would otherwise be considered ''critical'' are rated ''serious'' when'
               'a workaround is known.',
    'non-critical': 'The product, component or concept is working'
                    'in general, but lacks features, has irritating behavior, does'
                    'something wrong, or doesn''t match its documentation.',
}

# Rank order of severities, for sorting
SEVLIST = ['critical', 'grave', 'serious', 'important', 'does-not-build',
           'normal', 'non-critical', 'minor', 'wishlist', 'fixed']


def convert_severity(severity, type='debbugs'):
    "Convert severity names if needed."
    if type == 'debbugs':
        return {'non-critical': 'normal'}.get(severity, severity)
    elif type == 'gnats':
        return {'grave': 'critical',
                'important': 'serious',
                'normal': 'non-critical',
                'minor': 'non-critical',
                'wishlist': 'non-critical'}.get(severity, severity)
    else:
        return severity


# These packages are virtual in Debian; we don't look them up...
debother = {
    'bugs.debian.org': 'The bug tracking system, @bugs.debian.org',
    'buildd.debian.org': 'Problems and requests related to the Debian Buildds',
    'buildd.emdebian.org': 'Problems related to building packages for Emdebian',
    'cdimage.debian.org': 'CD Image issues',
    'cdrom': 'Installation system',
    'cloud.debian.org': 'Issues involving Debian images for public/private clouds',
    'contributors.debian.org': 'Issues with the Debian Contributors Website and coordination of maintenance',
    'd-i.debian.org': 'Issues regarding the d-i.debian.org service and general Debian Installer tasks',
    'debian-i18n': 'Requests regarding Internationalization (i18n) of the distribution',
    'debian-live': 'General problems with Debian Live systems',
    'ftp.debian.org': 'Problems with the FTP site and Package removal requests',
    'general': 'General problems (e.g. "many manpages are mode 755")',
    'installation-reports': 'Reports of installation problems with stable & testing',
    'jenkins.debian.org': 'Issues with the jenkins.debian.org service',
    'lists.debian.org': 'The mailing lists, debian-*@lists.debian.org',
    'manpages.debian.org': 'Issues with the Debian Manpages Website and coordination of maintenance',
    'mirrors': 'Problems with the official mirrors',
    'nm.debian.org': 'New Member process and nm.debian.org webpages',
    'pet.debian.net': 'The Debian Package Entropy Tracker',
    'piuparts.debian.org': 'Issues with the piuparts.debian.org service',
    'press': 'Press release issues',
    'project': 'Problems related to project administration',
    'qa.debian.org': 'The Quality Assurance group',
    'release.debian.org': 'Requests regarding Debian releases and release team tools',
    'release-notes': 'Problems with the Release Notes',
    'rtc.debian.org': 'Issues in the operation of the Debian RTC services which are not package-specific bugs',
    'security-tracker': 'The Debian Security Bug Tracker',
    'security.debian.org': 'The Debian Security Team',
    'snapshot.debian.org': 'Issues with the snapshot.debian.org service ',
    'spam': 'Spam (reassign spam to here so we can complain about it)',
    'sponsorship-requests': 'Requests for package review and sponsorship',
    'sso.debian.org': 'Problems and requests related to the Debian Single Sign On system',
    'summit.debconf.org': 'Problems and requests related to the DebConf Summit instance',
    'tech-ctte': 'The Debian Technical Committee (see the Constitution)',
    'tracker.debian.org': 'Issues with the Debian Package Tracker and coordination of its maintenance',
    'upgrade-reports': 'Reports of upgrade problems for stable & testing',
    'wiki.debian.org': 'Problems with the Debian wiki',
    'wnpp': 'Work-Needing and Prospective Packages list',
    'www.debian.org': 'Problems with the WWW site'
}

progenyother = {
    'debian-general': 'Any non-package-specific bug',
}


def handle_debian_ftp(package, bts, ui, fromaddr, timeout, online=True, http_proxy=None):
    body = reason = archs = section = priority = ''
    suite = 'unstable'
    headers = []
    pseudos = []
    query = True

    tag = ui.menu('What sort of request is this?  (If none of these '
                  'things mean anything to you, or you are trying to report '
                  'a bug in an existing package, please press Enter to '
                  'exit reportbug.)', {
                      'ROM': "Package removal - Request Of Maintainer.",
                      'RoQA': "Package removal - Requested by the QA team.",
                      'ROP': "Package removal - Request of Porter.",
                      'NBS': "Package removal - Not Built [by] Source.",
                      'NPOASR': "Package removal - Never Part Of A Stable Release.",
                      'NVIU': "Package removal - Newer Version In Unstable.",
                      'ANAIS': "Package removal - Architecture Not Allowed In Source.",
                      'ICE': "Package removal - Internal Compiler Error.",
                      'override': "Change override request.",
                      'other': "Not a package removal request, report other problems.",
                  }, 'Choose the request type: ', empty_ok=True)
    if not tag:
        ui.long_message('To report a bug in a package, use the name of the package, not ftp.debian.org.\n')
        raise SystemExit

    severity = 'normal'
    if tag == 'other':
        return
    else:
        prompt = 'Please enter the name of the package (either source of binary package): '
        package = ui.get_string(prompt)
        if not package:
            ui.log_message('You seem to want to report a generic bug, not request a removal\n')
            return

        ui.log_message('Checking status database...\n')
        info = utils.get_package_status(package)
        available = info[1]

        query = False
        if not available:
            info = utils.get_source_package(package)
            if info:
                info = utils.get_package_status(info[0][0])

        if not info:
            cont = ui.select_options(
                "This package doesn't appear to exist; continue?",
                'yN', {'y': 'Ignore this problem and continue.',
                       'n': 'Exit without filing a report.'})
            if cont == 'n':
                sys.exit(1)
        else:
            section, priority = info[16], info[10]

    if tag == 'override':
        headers.append('X-Debbugs-CC: debian-boot@lists.debian.org')
        ui.log_message('Your report will be carbon-copied to debian-boot.\n')

        # we handle here the override change request
        new_section = ui.menu('Select the new section', {
            'admin': "", 'cli-mono': "", 'comm': "", 'database': "",
            'debian-installer': "", 'debug': "", 'devel': "", 'doc': "",
            'editors': "", 'education': "", 'electronics': "",
            'embedded': "", 'fonts': "", 'games': "", 'gnome': "",
            'gnu-r': "", 'gnustep': "", 'graphics': "", 'hamradio': "",
            'haskell': "", 'httpd': "", 'interpreters': "",
            'introspection': "", 'java': "", "javascript": "",
            'kde': "", 'kernel': "",
            'libdevel': "", 'libs': "", 'lisp': "", 'localization': "",
            'mail': "", 'math': "", 'metapackages': "", 'misc': "",
            'net': "", 'news': "", 'ocaml': "", 'oldlibs': "",
            'otherosfs': "", 'perl': "", 'php': "", 'python': "",
            'ruby': "", 'rust': "",
            'science': "", 'shells': "", 'sound': "", 'tex': "",
            'text': "", 'utils': "", 'vcs': "", 'video': "", 'web': "",
            'x11': "", 'xfce': "", 'zope': "",
        }, 'Choose the section: ', default=section, empty_ok=True)
        if not new_section:
            new_section = section

        new_priority = ui.menu('Select the new priority', {
            'required': "",
            'important': "",
            'standard': "",
            'optional': "",
            'extra': "",
        }, 'Choose the priority: ', default=priority, empty_ok=True)
        if not new_priority:
            new_priority = priority

        if new_section == section and new_priority == priority:
            cont = ui.select_options(
                "You didn't change section nor priority: is this because it's "
                "ftp.debian.org override file that needs updating?",
                'Yn', {'y': 'ftp.debian.org override file needs updating',
                       'n': 'No, it\'s not the override file'})
            if cont == 'n':
                ui.long_message("There's nothing we can do for you, then; "
                                "exiting...")
                sys.exit(1)

        arch_section = ui.menu('Is this request for an archive section other than "main"?', {
            'main': "",
            'contrib': "",
            'non-free': "",
        }, 'Choose the archive section: ', default='main', empty_ok=True)
        if not arch_section:
            arch_section = 'main'

        if arch_section != 'main':
            subject = "override: %s:%s/%s %s" % (package, arch_section, new_section, new_priority)
        else:
            subject = "override: %s:%s/%s" % (package, new_section, new_priority)
        body = "(Describe here the reason for this change)"
    else:
        # we handle here the removal requests
        suite = ui.menu('Is the removal to be done in a suite other than'
                        ' "unstable"?  Don\'t select anything for "unstable"', {
                            'oldstable': "Old stable.",
                            'oldstable-proposed-updates': "Old stable proposed updates.",
                            'stable': "Stable.",
                            'stable-proposed-updates': "Stable proposed updates.",
                            'testing': "Testing only (NOT unstable)",
                            'testing-proposed-updates': "Testing proposed updates",
                            'experimental': "Experimental.",
                        }, 'Choose the suite: ', empty_ok=True)
        if not suite:
            suite = 'unstable'

        if suite not in ('testing', 'unstable', 'experimental'):
            headers.append('X-Debbugs-CC: debian-release@lists.debian.org')
            ui.log_message('Your report will be carbon-copied to debian-release.\n')

        why = 'Please enter the reason for removal: '
        reason = ui.get_string(why)
        if not reason:
            return

        partial = ui.select_options(
            "Is this removal request for specific architectures?",
            'yN', {'y': 'This is a partial (specific architectures) removal.',
                   'n': 'This removal is for all architectures.'})
        if partial == 'y':
            prompt = 'Please enter the arch list separated by a space: '
            archs = ui.get_string(prompt)
            if not archs:
                ui.long_message('Partial removal requests must have a list of architectures.\n')
                raise SystemExit

        if suite == 'testing' and archs:
            ui.long_message('Partial removal for testing; forcing suite to '
                            '\'unstable\', since it\'s the proper way to do that.')
            suite = 'unstable'
            body = '(please explain the reason for the removal here)\n\n' + \
                   'Note: this was a request for a partial removal from testing, ' + \
                   'converted in one for unstable'

        if archs:
            if suite != 'unstable':
                subject = 'RM: %s/%s [%s] -- %s; %s' % (package, suite, archs, tag, reason)
            else:
                subject = 'RM: %s [%s] -- %s; %s' % (package, archs, tag, reason)
        else:
            if suite != 'unstable':
                subject = 'RM: %s/%s -- %s; %s' % (package, suite, tag, reason)
            else:
                subject = 'RM: %s -- %s; %s' % (package, tag, reason)

        if suite == 'testing':
            ui.long_message('Please use release.debian.org pseudo-package and '
                            'report a bug there.')
            sys.exit(1)

    return (subject, severity, headers, pseudos, body, query)


def handle_debian_release(package, bts, ui, fromaddr, timeout, online=True, http_proxy=None):
    body = ''
    headers = []
    pseudos = []
    query = True
    archs = None
    version = None

    oldstable = utils.SUITE2CODENAME['oldstable']
    oldstable_pu = oldstable + '-pu'
    oldstable_backports = oldstable + '-backports'
    oldstable_security = oldstable + '-security'
    stable = utils.SUITE2CODENAME['stable']
    stable_pu = stable + '-pu'
    stable_backports = stable + '-backports'
    stable_security = stable + '-security'
    testing = utils.SUITE2CODENAME['testing']

    tag = ui.menu('What sort of request is this?  (If none of these '
                  'things mean anything to you, or you are trying to report '
                  'a bug in an existing package, please press Enter to '
                  'exit reportbug.)', {
                      'binnmu': "binNMU requests",
                      'britney': "testing migration script bugs",
                      'transition': "transition tracking",
                      'unblock': "unblock requests",
                      oldstable_pu: "%s proposed updates requests" % oldstable,
                      stable_pu: "%s proposed updates requests" % stable,
                      'rm': "Stable/Testing removal requests",
                      'other': "None of the other options",
                  }, 'Choose the request type: ', empty_ok=True)
    if not tag:
        ui.long_message('To report a bug in a package, use the name of the package, not release.debian.org.\n')
        raise SystemExit

    severity = 'normal'
    if tag == 'other':
        return

    if tag == 'britney':
        subject_britney = ui.get_string('Please enter the subject of the bug report: ')
        if not subject_britney:
            ui.long_message('No subject specified, exiting')
            sys.exit(1)
    else:
        # package checks code
        prompt = 'Please enter the name of the package: '
        package = ui.get_string(prompt)
        if not package:
            ui.log_message('You seem to want to report a generic bug.\n')
            return

        ui.log_message('Checking status database...\n')
        info = utils.get_package_status(package)
        available = info[1]

        query = False
        if not available:
            info = utils.get_source_package(package)
            if info:
                info = utils.get_package_status(info[0][0])

        if not info:
            cont = ui.select_options(
                "This package doesn't appear to exist; continue?",
                'yN', {'y': 'Ignore this problem and continue.',
                       'n': 'Exit without filing a report.'})
            if cont == 'n':
                sys.exit(1)
        else:
            package = info[12] or package

    if tag in ('binnmu', 'unblock', stable_pu, oldstable_pu, 'rm'):
        # FIXME: pu/rm should lookup the version elsewhere
        version = info and info[0]
        if online and tag.endswith('-pu'):
            try:
                version = list(checkversions.get_versions_available(package, timeout, (tag[:-3],)).values())[0]
            except IndexError:
                pass
        if version:
            cont = ui.select_options(
                "Latest version seems to be %s, is this the proper one ?" % (version),
                "Yn", {'y': "This is the correct version",
                       'n': "Enter the proper version"})
            if cont == 'n':
                version = None
        if not version:
            version = ui.get_string('Please enter the version of the package: ')
            if not version:
                ui.log_message("A version is required for action %s, not sending bug\n" % (tag))
                return

    if tag in ('binnmu', 'rm'):
        partial = ui.select_options(
            "Is this request for specific architectures?",
            'yN', {'y': 'This is a partial (specific architectures) request.',
                   'n': 'This request is for all architectures.'})
        if partial == 'y':
            if tag == 'rm':
                ui.long_message('The proper way to request a partial removal '
                                'from testing is to file a partial removal from unstable: '
                                'this way the package for the specified architectures will '
                                'be automatically removed from testing too. Please re-run '
                                'reportbug against ftp.debian.org package.')
                raise SystemExit
            prompt = 'Please enter the arch list separated by a space: '
            archs = ui.get_string(prompt)
            if not archs:
                ui.long_message('No architecture specified, skipping...')

    if tag == 'binnmu':
        suite = ui.menu("For which suite are you requesting this binNMU?"
                        "  Don't select anything for \"unstable\"", {
                            stable: "",
                            stable_backports: "",
                            stable_security: "",
                            oldstable: "",
                            oldstable_backports: "",
                            oldstable_security: "",
                            testing: "",
                            'experimental': "",
                        }, 'Choose the suite: ', empty_ok=True)
        if not suite:
            suite = 'unstable'

    pseudos.append("User: release.debian.org@packages.debian.org")
    if tag.endswith('-pu'):
        pseudos.append("Usertags: pu")
        pseudos.append("Tags: %s" % (tag[:-3]))
    else:
        pseudos.append("Usertags: %s" % (tag))

    if tag == 'binnmu':
        reason = ui.get_string("binNMU changelog entry: ")
        subject = "nmu: %s_%s" % (package, version)
        body = "nmu %s_%s . %s . %s . -m \"%s\"\n" % (package, version, archs or "ANY", suite, reason)
    elif tag == 'transition':
        subject = 'transition: %s' % (package)
        body = '(please explain about the transition: impacted packages, reason, ...\n' \
               ' for more info see: https://wiki.debian.org/Teams/ReleaseTeam/Transitions)\n'
        affected = '<Fill out>'
        good = '<Fill out>'
        bad = '<Fill out>'

        ui.long_message('To assist the release team, please fill in the following information. '
                        'You will be asked to provide package names of the library package(s) '
                        'that are the source of the transition.  If more than one library is '
                        'changing the name, please use a space separated list.  Alternatively '
                        'you can use a regex by enclosing the regex in slashes ("/").  Please '
                        'ensure that the "old" regex does not match the "new" packages.  '
                        'Example: old="/libapt-pkg4.10|libapt-inst1.2/ libept1" '
                        'new="/libapt-pkg4.12|libapt-inst1.5|libept1.4.12/". For further '
                        'reference, please refer to http://ben.debian.net/ .')

        prompt = 'Please enter old binary package name of the library (or a regex matching it):'
        tfrom = ui.get_string(prompt)
        if tfrom:
            prompt = 'Please enter new binary package name of the library (or a regex matching it):'
            tto = ui.get_string(prompt)
        else:
            tto = None
        if tfrom and tto:
            # Compute a ben file from this.

            # (quote if x does not start with a "/")
            quote = lambda x: (x[0] == '/' and x) or '"%s"' % x

            listbad = [quote(x) for x in tfrom.strip().split()]
            listgood = [quote(x) for x in tto.strip().split()]

            j = " | .depends ~ ".join
            affected = ".depends ~ " + j(listbad + listgood)
            good = ".depends ~ " + j(listgood)
            bad = ".depends ~ " + j(listbad)

        body += textwrap.dedent("""\

               Ben file:

               title = "%s";
               is_affected = %s;
               is_good = %s;
               is_bad = %s;

               """ % (package, affected, good, bad))

    elif tag == 'britney':
        subject = subject_britney
        body = ''
    elif tag == 'unblock':
        subject = 'unblock: %s/%s' % (package, version)
        body = textwrap.dedent("""\
                Please unblock package %s

                (explain the reason for the unblock here)

                (include/attach the debdiff against the package in testing)

                unblock %s/%s
                """ % (package, package, version))
    elif tag.endswith('-pu'):
        subject = '%s: package %s/%s' % (tag, package, version)
        body = '(please explain the reason for this update here)\n'
    elif tag == 'rm':
        subject = 'RM: %s/%s' % (package, version)
        body = '(explain the reason for the removal here)\n'

    return (subject, severity, headers, pseudos, body, query)


itp_template = textwrap.dedent("""\
    * Package name    : %(package)s
      Version         : x.y.z
      Upstream Author : Name <somebody@example.org>
    * URL             : http://www.example.org/
    * License         : (GPL, LGPL, BSD, MIT/X, etc.)
      Programming Lang: (C, C++, C#, Perl, Python, etc.)
      Description     : %(short_desc)s

    (Include the long description here.)

    Please also include as much relevant information as possible.
    For example, consider answering the following questions:
     - why is this package useful/relevant? is it a dependency for
       another package? do you use it? if there are other packages
       providing similar functionality, how does it compare?
     - how do you plan to maintain it? inside a packaging team
       (check list at https://wiki.debian.org/Teams)? are you
       looking for co-maintainers? do you need a sponsor?
""")


def handle_wnpp(package, bts, ui, fromaddr, timeout, online=True, http_proxy=None):
    short_desc = body = ''
    headers = []
    pseudos = []
    query = True

    tag = ui.menu('What sort of request is this?  (If none of these '
                  'things mean anything to you, or you are trying to report '
                  'a bug in an existing package, please press Enter to '
                  'exit reportbug.)', {
                      'O': "The package has been `Orphaned'. It needs a new maintainer as soon as possible.",
                      'RFA': "This is a `Request for Adoption'. Due to lack of time, resources, interest or something similar, the current maintainer is asking for someone else to maintain this package. They will maintain it in the meantime, but perhaps not in the best possible way. In short: the package needs a new maintainer.",
                      'RFH': "This is a `Request For Help'. The current maintainer wants to continue to maintain this package, but they need some help to do this because their time is limited or the package is quite big and needs several maintainers.",
                      'ITP': "This is an `Intent To Package'. Please submit a package description along with copyright and URL in such a report.",
                      'RFP': "This is a `Request For Package'. You have found an interesting piece of software and would like someone else to maintain it for Debian. Please submit a package description along with copyright and URL in such a report.",
                  }, 'Choose the request type: ', empty_ok=True)
    if not tag:
        ui.long_message('To report a bug in a package, use the name of the package, not wnpp.\n')
        raise SystemExit

    # keep asking for package name until one is entered
    package = ""

    while not package:
        if tag in ('RFP', 'ITP'):
            prompt = 'Please enter the proposed package name: '
        else:
            prompt = 'Please enter the package name: '
        package = ui.get_string(prompt)
        if not utils.check_package_name(package):
            ui.long_message('Invalid package name')
            package = ""

    ui.log_message('Checking status database...\n')
    info = utils.get_package_status(package, avail=True)
    available = info[1]

    severity = 'normal'
    if tag in ('ITP', 'RFP'):
        if available and (not online or checkversions.check_available(
                package, '0', timeout, http_proxy=http_proxy)):
            if not ui.yes_no(
                    ('A package called %s already appears to exist (at least on '
                     'your system); continue?' % package),
                    'Ignore this problem and continue.  If you have '
                    'already locally created a package with this name, this '
                    'warning message may have been produced in error.',
                    'Exit without filing a report.', default=0):
                sys.exit(1)

        severity = 'wishlist'

        # keep asking for short description until one is entered
        short_desc = ""

        while not short_desc:
            short_desc = ui.get_string(
                'Please briefly describe this package; this should be an '
                'appropriate short description for the eventual package: ')

        if tag == 'ITP':
            headers.append('X-Debbugs-CC: debian-devel@lists.debian.org')
            pseudos.append('Owner: {}'.format(
                email.header.make_header(email.header.decode_header(fromaddr))))
            ui.log_message('Your report will be carbon-copied to debian-devel, '
                           'per Debian policy.\n')

        body = itp_template % vars()
    elif tag in ('O', 'RFA', 'RFH'):
        severity = 'normal'
        query = False
        if not available:
            info = utils.get_source_package(package)
            if info:
                info = utils.get_package_status(info[0][0])

        if not info:
            cont = ui.select_options(
                "This package doesn't appear to exist; continue?",
                'yN', {'y': 'Ignore this problem and continue.',
                       'n': 'Exit without filing a report.'})
            if cont == 'n':
                sys.exit(1)
            short_desc = long_desc = ''
        else:
            short_desc = info[11] or ''
            package = info[12] or package
            long_desc = info[13]

        if tag == 'O' and info and info[9] in \
                ('required', 'important', 'standard'):
            severity = 'important'

        if tag == 'RFH':
            headers.append('X-Debbugs-CC: debian-devel@lists.debian.org')
            ui.log_message('Your request will be carbon-copied to debian-devel, '
                           'per Debian policy.\n')

        if long_desc:
            orphstr = 'intend to orphan'
            if tag == 'RFA':
                orphstr = 'request an adopter for'
            elif tag == 'RFH':
                orphstr = 'request assistance with maintaining'

            body = ('I %s the %s package.\n\n'
                    'The package description is:\n') % (orphstr, package)
            body = body + long_desc + '\n'

    if short_desc:
        subject = '%s: %s -- %s' % (tag, package, short_desc)
    else:
        subject = '%s: %s' % (tag, package)

    return (subject, severity, headers, pseudos, body, query)


def dpkg_infofunc():
    debarch = utils.get_arch()
    utsmachine = os.uname()[4]
    multiarch = utils.get_multiarch()
    if debarch:
        if utsmachine == debarch:
            debinfo = 'Architecture: %s\n' % debarch
        else:
            debinfo = 'Architecture: %s (%s)\n' % (debarch, utsmachine)
    else:
        debinfo = 'Architecture: ? (%s)\n' % utsmachine
    if multiarch:
        debinfo += 'Foreign Architectures: %s\n' % multiarch
    debinfo += '\n'
    return debinfo


def debian_infofunc():
    return utils.get_debian_release_info() + dpkg_infofunc()


def ubuntu_infofunc():
    return utils.lsb_release_info() + dpkg_infofunc()


def generic_infofunc():
    utsmachine = os.uname()[4]
    return utils.lsb_release_info() + 'Architecture: %s\n\n' % utsmachine


# Supported servers
# Theoretically support for GNATS and Jitterbug could be added here.
SYSTEMS = {'debian':
           {'name': 'Debian', 'email': '%s@bugs.debian.org',
            'btsroot': 'http://www.debian.org/Bugs/',
            'otherpkgs': debother,
            'nonvirtual': ['linux-image', 'kernel-image'],
            'specials':
                {'wnpp': handle_wnpp,
                 'ftp.debian.org': handle_debian_ftp,
                 'release.debian.org': handle_debian_release},
            # Dependency packages
            'deppkgs': ('gcc', 'g++', 'cpp', 'gcj', 'gpc', 'gobjc',
                        'chill', 'gij', 'g77', 'python', 'python-base',
                        'x-window-system-core', 'x-window-system'),
            'cgiroot': 'https://bugs.debian.org/cgi-bin/',
            'infofunc': debian_infofunc,
            },
           'ubuntu':
               {'name': 'Ubuntu', 'email': 'ubuntu-users@lists.ubuntu.com',
                'type': 'mailto',
                'infofunc': ubuntu_infofunc,
                },
           'guug':
               {'name': 'GUUG (German Unix User Group)',
                'email': '%s@bugs.guug.de', 'query-dpkg': False},
           }

CLASSES = {
    'sw-bug': 'The problem is a bug in the software or code.  For'
              'example, a crash would be a sw-bug.',
    'doc-bug': 'The problem is in the documentation.  For example,'
               'an error in a man page would be a doc-bug.',
    'change-request': 'You are requesting a new feature or a change'
                      'in the behavior of software, or are making a suggestion.  For'
                      'example, if you wanted reportbug to be able to get your local'
                      'weather forecast, as well as report bugs, that would be a'
                      'change-request.',
}

CLASSLIST = ['sw-bug', 'doc-bug', 'change-request']

CRITICAL_TAGS = {
    'security': 'This problem is a security vulnerability in Debian.',
}

EXPERT_TAGS = {
    'security': 'This problem is a security vulnerability in Debian.',
}

TAGS = {
    'patch': 'You are including a patch to fix this problem.',
    'upstream': 'This bug applies to the upstream part of the package.',
    'd-i': 'This bug is relevant to the development of debian-installer.',
    'ipv6': 'This bug affects support for Internet Protocol version 6.',
    'lfs': 'This bug affects support for large files (over 2 gigabytes).',
    'l10n': 'This bug reports a localization/internationalization issue.',
    'a11y': 'This bug is relevant to the accessibility of the package.',
    'newcomer': 'This bug has a known solution but the maintainer requests someone else implement it.',
}


def get_tags(severity='', mode=utils.MODE_NOVICE):
    """Returns the current tags list.

    If severity is release critical, than add additional tags not always present.
    If mode is higher than STANDARD, then add suite tags."""

    tags = TAGS.copy()

    if severity in ('grave', 'critical', 'serious'):
        tags.update(CRITICAL_TAGS)

    if mode > utils.MODE_STANDARD:
        tags.update(EXPERT_TAGS)

    return tags


def yn_bool(setting):
    if setting:
        if str(setting) == 'no':
            return 'no'
        return 'yes'
    else:
        return 'no'


def cgi_report_url(system, number, archived=False, mbox=False):
    root = SYSTEMS[system].get('cgiroot')
    if root:
        return '%sbugreport.cgi?bug=%d&archived=%s&mbox=%s' % (
            root, number, archived, yn_bool(mbox))
    return None


def cgi_package_url(system, package, archived=False, source=False,
                    repeatmerged=True, version=None):
    root = SYSTEMS[system].get('cgiroot')
    if not root:
        return None

    # package = urllib.quote_plus(package.lower())
    if source:
        query = {'src': package.lower()}
    else:
        query = {'pkg': package.lower()}

    query['repeatmerged'] = yn_bool(repeatmerged)
    query['archived'] = yn_bool(archived)

    if version:
        query['version'] = str(version)

    qstr = urllib.parse.urlencode(query)
    # print qstr
    return '%spkgreport.cgi?%s' % (root, qstr)


# TODO: to be removed
def package_url(system, package, mirrors=None, source=False,
                repeatmerged=True):
    btsroot = get_btsroot(system, mirrors)
    package = urllib.parse.quote_plus(package.lower())
    return btsroot + ('db/pa/l%s.html' % package)


# TODO: to be removed
def report_url(system, number, mirrors=None):

    number = str(number)
    if len(number) < 2:
        return None
    btsroot = get_btsroot(system, mirrors)
    return btsroot + ('db/%s/%s.html' % (number[:2], number))


def get_package_url(system, package, mirrors=None, source=False,
                    archived=False, repeatmerged=True):
    return (cgi_package_url(system, package, archived, source, repeatmerged) or
            package_url(system, package, mirrors, source, repeatmerged))


def get_report_url(system, number, mirrors=None, archived=False, mbox=False):
    return (cgi_report_url(system, number, archived, mbox) or
            report_url(system, number, mirrors))


def parse_bts_url(url):
    bits = url.split(':', 1)
    if len(bits) != 2:
        return None

    type, loc = bits
    if loc.startswith('//'):
        loc = loc[2:]
    while loc.endswith('/'):
        loc = loc[:-1]
    return type, loc


# Dynamically add any additional systems found
for origin in glob.glob('/etc/dpkg/origins/*'):
    try:
        fp = open(origin, errors='backslashreplace')
        system = os.path.basename(origin)
        SYSTEMS[system] = SYSTEMS.get(system, {'otherpkgs': {},
                                               'query-dpkg': True,
                                               'mirrors': {},
                                               'cgiroot': None})
        for line in fp:
            try:
                (header, content) = line.split(': ', 1)
                header = header.lower()
                content = content.strip()
                if header == 'vendor':
                    SYSTEMS[system]['name'] = content
                elif header == 'bugs':
                    (type, root) = parse_bts_url(content)
                    SYSTEMS[system]['type'] = type
                    if type == 'debbugs':
                        SYSTEMS[system]['btsroot'] = 'http://' + root + '/'
                        SYSTEMS[system]['email'] = '%s@' + root
                    elif type == 'mailto':
                        SYSTEMS[system]['btsroot'] = None
                        SYSTEMS[system]['email'] = root
                    else:
                        # We don't know what to do...
                        pass
            except ValueError:
                pass
        fp.close()
    except IOError:
        pass


# TODO: to be removed
def parse_html_report(number, url, http_proxy, timeout, followups=False, cgi=True):
    page = open_url(url, http_proxy, timeout)
    if not page:
        return None

    parser = BTSParser(cgi=cgi, followups=followups)
    for line in page.splitlines():
        parser.feed(line + '\n')
    parser.close()

    items = parser.preblock
    title = "#%d: %s" % (number, parser.title)

    if not followups:
        items = [items]

    output = []
    for stuff in items:
        parts = stuff.split('\n\n')
        match = re.search('^Date: (.*)$', parts[0], re.M | re.I)
        date_submitted = ''
        if match:
            date_submitted = 'Date: %s\n' % match.group(1)

        stuff = ('\n\n'.join(parts[1:])).rstrip()
        if not stuff:
            continue

        item = date_submitted + stuff + os.linesep
        output.append(item)

    if not output:
        return None

    return (title, output)


# XXX: Need to handle charsets properly
def parse_mbox_report(number, url, http_proxy, timeout, followups=False):
    page = open_url(url, http_proxy, timeout)
    if not page:
        return None

    # Make this seekable
    wholefile = io.StringIO(page)

    mbox = mailbox.UnixMailbox(wholefile, msgfactory)
    title = ''

    output = []
    for message in mbox:
        if not message:
            pass

        subject = message.get('Subject')
        if not title:
            title = subject

        date = message.get('Date')
        fromhdr = message.get('From')

        body = entry = ''
        for part in message.walk():
            if part.get_content_type() == 'text/plain' and not body:
                body = part.get_payload(None, True)

        if fromhdr:
            entry += 'From: %s%s' % (fromhdr, os.linesep)

        if subject and subject != title:
            entry += 'Subject: %s%s' % (subject, os.linesep)

        if date:
            entry += 'Date: %s%s' % (date, os.linesep)

        if entry:
            entry += os.linesep

        entry += body.rstrip('\n') + os.linesep

        output.append(entry)

    if not output:
        return None

    title = "#%d: %s" % (number, title)
    return (title, output)


def get_btsroot(system, mirrors=None):
    if mirrors:
        alternates = SYSTEMS[system].get('mirrors')
        for mirror in mirrors:
            if mirror in alternates:
                return alternates[mirror]
    return SYSTEMS[system].get('btsroot', '')


def get_reports(package, timeout, system='debian', mirrors=None, version=None,
                http_proxy='', archived=False, source=False):
    if system == 'debian':
        if isinstance(package, str):
            if source:
                pkg_filter = 'src'
            else:
                pkg_filter = 'package'
            bugs = debianbts.get_bugs(pkg_filter, package)
        else:
            bugs = list(map(int, package))

        try:
            # retrieve bugs and generate the hierarchy
            stats = debianbts.get_status(bugs)
        except:
            raise QuertBTSError

        d = defaultdict(list)
        for s in stats:
            # We now return debianbts.Bugreport objects, containing all the info
            # for a bug, so UIs can extract them as needed
            d[s.severity].append(s)

        # keep the bugs ordered per severity
        # XXX: shouldn't it be something UI-related?
        #
        # The hierarchy is a list of tuples:
        #     (description of the severity, list of bugs for that severity)
        hier = []
        for sev in SEVLIST:
            if sev in d:
                hier.append(('Bugs with severity %s' % sev, d[sev]))

        return (len(bugs), 'Bug reports for %s' % package, hier)

    # XXX: is the code below used at all now? can we remove it?
    if isinstance(package, str):
        if SYSTEMS[system].get('cgiroot'):
            try:
                result = get_cgi_reports(package, timeout, system, http_proxy, archived,
                                         source, version=version)
            except:
                raise NoNetwork
            if result:
                return result

        url = package_url(system, package, mirrors, source)
        try:
            page = open_url(url, http_proxy, timeout)
        except:
            raise NoNetwork
        if not page:
            return (0, None, None)

        # content = page.read()
        # if 'Maintainer' not in content:
        #    return (0, None, None)

        parser = BTSParser()
        for line in page.splitlines():
            parser.feed(line + '\n')
        parser.close()

        return parser.bugcount, parser.title, parser.hierarchy

    # A list of bug numbers
    this_hierarchy = []
    package = [int(x) for x in package]
    package.sort()
    for bug in package:
        result = get_report(bug, timeout, system, mirrors, http_proxy, archived)
        if result:
            title, body = result
            this_hierarchy.append(title)
            # print title

    title = "Multiple bug reports"
    bugcount = len(this_hierarchy)
    hierarchy = [('Reports', this_hierarchy)]

    return bugcount, title, hierarchy


def get_report(number, timeout, system='debian', mirrors=None,
               http_proxy='', archived=False, followups=False):
    number = int(number)

    if system == 'debian':
        status = debianbts.get_status(number)[0]
        log = debianbts.get_bug_log(number)

        # add Date/Subject/From headers to the msg bodies
        bodies = []
        for l in log:
            h = l['message']
            hdrs = []
            for i in ['Date', 'Subject', 'From']:
                if i in h:
                    hdrs.append(i + ': ' + h.get(i))
            bodies.append('\n'.join(sorted(hdrs)) + '\n\n' + l['body'])

        # returns the bug status and a list of mail bodies
        return (status, bodies)

    if SYSTEMS[system].get('cgiroot'):
        result = get_cgi_report(number, timeout, system, http_proxy,
                                archived, followups)
        if result:
            return result

    url = report_url(system, number, mirrors)
    if not url:
        return None

    return parse_html_report(number, url, http_proxy, timeout, followups, cgi=False)
