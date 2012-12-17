% This file is part of "Enms" (http://sourceforge.net/projects/enms/)
% Copyright (C) 2012 <Sébastien Serre sserre.bx@gmail.com>
% 
% Enms is a Network Management System aimed to manage and monitor SNMP
% targets, monitor network hosts and services, provide a consistent
% documentation system and tools to help network professionals
% to have a wide perspective of the networks they manage.
% 
% Enms is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
% 
% Enms is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with Enms.  If not, see <http://www.gnu.org/licenses/>.
{application, main_ifs,
	[
		{description, "ENMS core system"},
		{vsn, "0.1.0"},
		{modules, [
                ifs_app,
                ifs_sup,
                ifs_srv,
                ifs_mpd,
                ifs_auth_ldap,
                asncli,
                ssl_client,
                ssl_client_sup,
                ssl_server_sup,
                ssl_listener,
                tcp_client,
                tcp_client_sup,
                tcp_server_sup,
                tcp_listener
            ]},
		{registered, [
                ifs_sup,
                ifs_server,
                ifs_mpd,
                ifs_auth_ldap,
                ssl_client_sup,
                ssl_server_sup,
                ssl_listener
            ]},
		{applications, [kernel, stdlib, crypto, public_key, ssl]},

		% mandatory
		{mod, {ifs_app, []}}
	]
}.