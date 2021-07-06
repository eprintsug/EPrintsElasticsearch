###############################################################################
#
#  ElasticSearch central configuration
#
###############################################################################
#
#  Copyright 2020 University of Zurich. All Rights Reserved.
#
#  Martin Brändle
#  Jens Witzel
#  Zentrale Informatik
#  Universität Zürich
#  Stampfenbachstr. 73
#  CH-8006 Zürich
#
#  The plug-ins are free software; you can redistribute them and/or modify
#  them under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  The plug-ins are distributed in the hope that they will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with EPrints 3; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
###############################################################################

$c->{es}->{scheme} =         'https';
$c->{es}->{host} =           [ 
                                'host1.domain.com',
                                'host2.domain.com',
                                'host3.domain.com',
                             ];
$c->{es}->{port} =           '9200';
$c->{es}->{path} =           '/';
$c->{es}->{index} =          'name_of_es_index';
$c->{es}->{info}->{admin} =  'es_index_admin:password';
$c->{es}->{info}->{user} =   'es_index_user:password';
$c->{es}->{cxn} =            'LWP';
$c->{es}->{client} =         '7_0::Direct';

$c->{es}->{static_settings} = {
	"number_of_shards" => 1,
	"number_of_replicas" => 2,
};

$c->{es}->{dynamic_settings} = {
	"index.mapping.nested_fields.limit" => 50,
};

# The datasets to be indexed
$c->{es}->{datasets} = [ 'eprint' ];

# The citation styles to be used to render the items in the result list
$c->{es}->{citation_styles} = [ 
	'es_title', 
	'es_contributors', 
	'es_publication', 
];

# nested languages, to check for exist and highlight nested title or citations
$c->{es}->{nested_languages} = [ 
	'eng',
	'deu',
	'fra',
	'ita',
	'default'
];

# Max number of export. 1 > max_export > 10.000 (ES standard max)
$c->{es}->{max_export} =           '1000';
# Request Timeout cause expensive exports need time
$c->{es}->{request_timeout} =           '60';
