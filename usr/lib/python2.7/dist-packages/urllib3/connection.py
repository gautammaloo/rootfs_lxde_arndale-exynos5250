# urllib3/connection.py
# Copyright 2008-2013 Andrey Petrov and contributors (see CONTRIBUTORS.txt)
#
# This module is part of urllib3 and is released under
# the MIT License: http://www.opensource.org/licenses/mit-license.php

import sys
import socket
from socket import timeout as SocketTimeout

try:  # Python 3
    from http.client import HTTPConnection as _HTTPConnection, HTTPException
except ImportError:
    from httplib import HTTPConnection as _HTTPConnection, HTTPException


class DummyConnection(object):
    "Used to detect a failed ConnectionCls import."
    pass


try:  # Compiled with SSL?
    HTTPSConnection = DummyConnection
    import ssl
    BaseSSLError = ssl.SSLError
except (ImportError, AttributeError):  # Platform-specific: No SSL.
    ssl = None

    class BaseSSLError(BaseException):
        pass


from .exceptions import (
    ConnectTimeoutError,
)
from ssl import match_hostname
import six
from .util import (
    assert_fingerprint,
    resolve_cert_reqs,
    resolve_ssl_version,
    ssl_wrap_socket,
)


port_by_scheme = {
    'http': 80,
    'https': 443,
}


class HTTPConnection(_HTTPConnection, object):
    """
    Based on httplib.HTTPConnection but provides an extra constructor
    backwards-compatibility layer between older and newer Pythons.

    Additional keyword parameters are used to configure attributes of the connection.
    Accepted parameters include:

      - ``strict``: See the documentation on :class:`urllib3.connectionpool.HTTPConnectionPool`
      - ``source_address``: Set the source address for the current connection.

        .. note:: This is ignored for Python 2.6. It is only applied for 2.7 and 3.x

      - ``socket_options``: Set specific options on the underlying socket. If not specified, then
        defaults are loaded from ``HTTPConnection.default_socket_options`` which includes disabling
        Nagle's algorithm (sets TCP_NODELAY to 1) unless the connection is behind a proxy.

        For example, if you wish to enable TCP Keep Alive in addition to the defaults,
        you might pass::

            HTTPConnection.default_socket_options + [
                (socket.SOL_SOCKET, socket.SO_KEEPALIVE, 1),
            ]

        Or you may want to disable the defaults by passing an empty list (e.g., ``[]``).
    """

    default_port = port_by_scheme['http']

    #: Disable Nagle's algorithm by default.
    #: ``[(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)]``
    default_socket_options = [(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)]

    def __init__(self, *args, **kw):
        if six.PY3:  # Python 3
            kw.pop('strict', None)
        if sys.version_info < (2, 7):  # Python 2.6 and older
            kw.pop('source_address', None)

        # Pre-set source_address in case we have an older Python like 2.6.
        self.source_address = kw.get('source_address')

        #: The socket options provided by the user. If no options are
        #: provided, we use the default options.
        self.socket_options = kw.pop('socket_options', self.default_socket_options)

        # Superclass also sets self.source_address in Python 2.7+.
        _HTTPConnection.__init__(self, *args, **kw)

    def _new_conn(self):
        """ Establish a socket connection and set nodelay settings on it.

        :return: New socket connection.
        """
        extra_args = []
        if self.source_address:  # Python 2.7+
            extra_args.append(self.source_address)

        try:
            conn = socket.create_connection(
                (self.host, self.port), self.timeout, *extra_args)

        except SocketTimeout:
            raise ConnectTimeoutError(
                self, "Connection to %s timed out. (connect timeout=%s)" %
                (self.host, self.timeout))

        # Set options on the socket.
        self._set_options_on(conn)

        return conn

    def _prepare_conn(self, conn):
        self.sock = conn
        # the _tunnel_host attribute was added in python 2.6.3 (via
        # http://hg.python.org/cpython/rev/0f57b30a152f) so pythons 2.6(0-2) do
        # not have them.
        if getattr(self, '_tunnel_host', None):
            # TODO: Fix tunnel so it doesn't depend on self.sock state.
            self._tunnel()
            # Mark this connection as not reusable
            self.auto_open = 0

    def _set_options_on(self, conn):
        # Disable all socket options if the user passes ``socket_options=None``
        if self.socket_options is None:
            return

        for opt in self.socket_options:
            conn.setsockopt(*opt)

    def connect(self):
        conn = self._new_conn()
        self._prepare_conn(conn)


class HTTPSConnection(HTTPConnection):
    default_port = port_by_scheme['https']

    def __init__(self, host, port=None, key_file=None, cert_file=None,
                 strict=None, timeout=socket._GLOBAL_DEFAULT_TIMEOUT, **kw):

        HTTPConnection.__init__(self, host, port, strict=strict,
                                timeout=timeout, **kw)

        self.key_file = key_file
        self.cert_file = cert_file

        # Required property for Google AppEngine 1.9.0 which otherwise causes
        # HTTPS requests to go out as HTTP. (See Issue #356)
        self._protocol = 'https'

    def connect(self):
        conn = self._new_conn()
        self._prepare_conn(conn)
        self.sock = ssl.wrap_socket(conn, self.key_file, self.cert_file)


class VerifiedHTTPSConnection(HTTPSConnection):
    """
    Based on httplib.HTTPSConnection but wraps the socket with
    SSL certification.
    """
    cert_reqs = None
    ca_certs = None
    ssl_version = None

    def set_cert(self, key_file=None, cert_file=None,
                 cert_reqs=None, ca_certs=None,
                 assert_hostname=None, assert_fingerprint=None):

        self.key_file = key_file
        self.cert_file = cert_file
        self.cert_reqs = cert_reqs
        self.ca_certs = ca_certs
        self.assert_hostname = assert_hostname
        self.assert_fingerprint = assert_fingerprint

    def connect(self):
        # Add certificate verification
        conn = self._new_conn()

        resolved_cert_reqs = resolve_cert_reqs(self.cert_reqs)
        resolved_ssl_version = resolve_ssl_version(self.ssl_version)

        hostname = self.host
        if getattr(self, '_tunnel_host', None):
            # _tunnel_host was added in Python 2.6.3
            # (See: http://hg.python.org/cpython/rev/0f57b30a152f)

            self.sock = conn
            # Calls self._set_hostport(), so self.host is
            # self._tunnel_host below.
            self._tunnel()
            # Mark this connection as not reusable
            self.auto_open = 0

            # Override the host with the one we're requesting data from.
            hostname = self._tunnel_host

        # Wrap socket using verification with the root certs in
        # trusted_root_certs
        self.sock = ssl_wrap_socket(conn, self.key_file, self.cert_file,
                                    cert_reqs=resolved_cert_reqs,
                                    ca_certs=self.ca_certs,
                                    server_hostname=hostname,
                                    ssl_version=resolved_ssl_version)

        if resolved_cert_reqs != ssl.CERT_NONE:
            if self.assert_fingerprint:
                assert_fingerprint(self.sock.getpeercert(binary_form=True),
                                   self.assert_fingerprint)
            elif self.assert_hostname is not False:
                match_hostname(self.sock.getpeercert(),
                               self.assert_hostname or hostname)


if ssl:
    # Make a copy for testing.
    UnverifiedHTTPSConnection = HTTPSConnection
    HTTPSConnection = VerifiedHTTPSConnection
