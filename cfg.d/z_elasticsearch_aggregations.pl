###############################################################################
#
#  ElasticSearch aggregation fields configuration
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

#
# This is not a list of EPrints field names, but a list of field names used within 
# the ElasticSearch index. The exact mapping from the EPrints field(s) and value(s)
# to the aggregation fields is defined within z_elasticsearch_mappings.pl and
# z_elasticsearch_index.pl .
# Aggregation fields get an "agg_" prefix prepended to their names.
#
#  name: name of aggregation field
#  type: can have two values
#    key -> original value/s is/are taken and the field is named agg_{name}_key
#    language --> for each GUI language {lang}, field is named agg_{name}_{lang}
#      and the corresponding language values (phrase or database values) are indexed
#
#  some extra gui features: gui_order and gui_isfilterable howto display aggs; gui_sort (for the moment, only pubyear makes sense)

$c->{es}->{aggs} = [ 
  {
    name => 'pubyear',
    type => 'key',
    size => '30',
    order => {
               '_term' => 'desc'
             },
    gui_order => '10',
    gui_isfilterable => 'false',
    gui_sort => 'true',
  },
  {
    name => 'name',
    type => 'key',
    size => '300',
    gui_order => '15',
    gui_isfilterable => 'true',
  },
  {
    name => 'subject',
    type => 'language',
    size => '300',
    gui_order => '20',
    gui_isfilterable => 'true',
  },
  {
    name => 'pubtype',
    type => 'language',
    size => '30',
    gui_order => '25',
    gui_isfilterable => 'false',
  },
  {
    name => 'hasfulltext',
    type => 'language',
    size => '30',
    gui_order => '30',
    gui_isfilterable => 'false',
  },
  {
    name => 'accessrights',
    type => 'language',
    size => '30',
    gui_order => '35',
    gui_isfilterable => 'false',
  },
  {
    name => 'journalseries',
    type => 'key',
    size => '300',
    gui_order => '40',
    gui_isfilterable => 'true',
  },
  {
    name => 'dewey',
    type => 'language',
    size => '30',
    gui_order => '45',
    gui_isfilterable => 'true',
  },
  {
    name => 'language',
    type => 'language',
    size => '30',
    gui_order => '50',
    gui_isfilterable => 'false',
  },
  {
    name => 'affiliation',
    type => 'key',
    size => '300',
    gui_order => '55',
    gui_isfilterable => 'true',
  },
];
