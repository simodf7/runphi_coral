#
# checkversions.py - Find if the installed version of a package is the latest
#
#   Written by Chris Lawrence <lawrencc@debian.org>
#   (C) 2002-08 Chris Lawrence
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

import sys
import urllib.request, urllib.error, urllib.parse

from . import utils
from .urlutils import open_url
from reportbug.exceptions import (
    NoNetwork,
)

# needed to parse new.822
from debian.deb822 import Deb822
from debian import debian_support

RMADISON_URL = 'https://qa.debian.org/madison.php?package=%s&text=on'
INCOMING_URL = 'http://incoming.debian.org/'
NEWQUEUE_URL = 'http://ftp-master.debian.org/new.822'


## This needs to be adapted now that incoming is an APT repository
# class IncomingParser(sgmllib.SGMLParser):
#     def __init__(self, package, arch='i386'):
#         sgmllib.SGMLParser.__init__(self)
#         self.found = []
#         self.savedata = None
#         arch = r'(?:all|' + re.escape(arch) + ')'
#         self.package = re.compile(re.escape(package) + r'_([^_]+)_' + arch + '.deb')
#
#     def start_a(self, attrs):
#         for attrib, value in attrs:
#             if attrib.lower() != 'href':
#                 continue
#
#             mob = self.package.match(value)
#             if mob:
#                 self.found.append(mob.group(1))


def compare_versions(current, upstream):
    """Return 1 if upstream is newer than current, -1 if current is
    newer than upstream, and 0 if the same."""
    if not current or not upstream:
        return 0
    return debian_support.version_compare(upstream, current)


def later_version(a, b):
    if compare_versions(a, b) > 0:
        return b
    return a


def get_versions_available(package, timeout, dists=None, http_proxy=None, arch='i386'):
    if not dists:
        dists = ('oldstable', 'stable', 'testing', 'unstable', 'experimental')

    arch = utils.get_arch()

    url = RMADISON_URL % package
    url += '&s=' + ','.join(dists)
    # select only those lines that refers to source pkg
    # or to binary packages available on the current arch
    url += '&a=source,all,' + arch
    try:
        page = open_url(url)
    except NoNetwork:
        return {}
    except urllib.error.HTTPError as x:
        print("Warning:", x, file=sys.stderr)
        return {}
    if not page:
        return {}

    # read the content of the page, remove spaces, empty lines
    content = page.replace(' ', '').strip()

    versions = {}
    for line in content.split('\n'):
        l = line.split('|')
        # skip lines not having the right number of fields
        if len(l) != 4:
            continue
        # map suites name (returned by madison) to dist name
        dist = utils.CODENAME2SUITE.get(l[2], l[2])
        versions[dist] = l[1]

    return versions


def get_newqueue_available(package, timeout, dists=None, http_proxy=None, arch='i386'):
    if dists is None:
        dists = ('unstable (new queue)',)
    try:
        page = open_url(NEWQUEUE_URL, http_proxy, timeout)
    except NoNetwork:
        return {}
    except urllib.error.HTTPError as x:
        print("Warning:", x, file=sys.stderr)
        return {}
    if not page:
        return {}

    versions = {}

    # iter over the entries, one paragraph at a time
    for para in Deb822.iter_paragraphs(page):
        if para['Source'] == package:
            k = para['Distribution'] + ' (' + para['Queue'] + ')'
            # in case of multiple versions, choose the bigger
            versions[k] = max(para['Version'].split())

    return versions


def get_incoming_version(package, timeout, http_proxy=None, arch='i386'):
    try:
        page = open_url(INCOMING_URL, http_proxy, timeout)
    except NoNetwork:
        return None
    except urllib.error.HTTPError as x:
        print("Warning:", x, file=sys.stderr)
        return None
    if not page:
        return None

    # parser = IncomingParser(package, arch)
    # for line in page:
    #     parser.feed(line)
    # parser.close()
    # try:
    #     page.fp._sock.recv = None
    # except:
    #     pass
    # page.close()

    #if parser.found:
    #    found = parser.found
    #    del parser
    #    return reduce(later_version, found, '0')

    del page
    #del parser
    return None


def check_available(package, version, timeout, dists=None,
                    check_incoming=True, check_newqueue=True,
                    http_proxy=None, arch='i386'):
    avail = {}

    if check_incoming:
        iv = get_incoming_version(package, timeout, http_proxy, arch)
        if iv:
            avail['incoming'] = iv
    stuff = get_versions_available(package, timeout, dists, http_proxy, arch)
    avail.update(stuff)
    if check_newqueue:
        srcpackage = utils.get_source_name(package)
        if srcpackage is None:
            srcpackage = package
        stuff = get_newqueue_available(srcpackage, timeout, dists, http_proxy, arch)
        avail.update(stuff)
        # print gc.garbage, stuff

    new = {}
    newer = 0
    for dist in avail:
        if dist == 'incoming':
            if ':' in version:
                ver = version.split(':', 1)[1]
            else:
                ver = version
            comparison = compare_versions(ver, avail[dist])
        else:
            comparison = compare_versions(version, avail[dist])
        if comparison > 0:
            new[dist] = avail[dist]
        elif comparison < 0:
            newer += 1
    too_new = (newer and newer == len(avail))
    return new, too_new
