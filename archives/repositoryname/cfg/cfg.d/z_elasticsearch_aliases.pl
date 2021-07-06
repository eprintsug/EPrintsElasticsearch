###############################################################################
#
#  Elasticsearch alias fields configuration
#
###############################################################################
#
#  Copyright 2021 University of Zurich. All Rights Reserved.
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
# A list of Elasticsearch alias field names

$c->{es}->{aliases}->{eprint} = [ 
  {
    alias => 'AB',
    path => "metadata.eprint.abstract",
    expand => 1,
  },
  {
    alias => 'AF',
    path => "metadata.eprint.contributor_search.organisation",
    expand => 0,
  },
  {
    alias => 'AU',
    path => "metadata.eprint.contributor_search.name",
    expand => 0,
  },
  {
    alias => 'BT',
    path => "metadata.eprint.book_title",
    expand => 0,
  },
  {
    alias => 'CC',
    path => "agg_subject",
    expand => 1,
  },
  {
    alias => 'CO',
    path => "metadata.eprint.contributor_search.country",
    expand => 0,
  },
  {
    alias => 'CS',
    path => "metadata.eprint.chair_subject",
    expand => 0,
  },
  {
    alias => 'DOI',
    path => "metadata.eprint.doi",
    expand => 0,
  },
  {
    alias => 'EPID',
    path => "id",
    expand => 0,
    range => 1,
  },
  {
    alias => 'FA',
    path => "metadata.eprint.fulltext_available",
    expand => 0,
  },
  {
    alias => 'IS',
    path => "metadata.eprint.number",
    expand => 0,
  },
  {
    alias => 'ISBN',
    path => "metadata.eprint.isbn",
    expand => 0,
  },
  {
    alias => 'ISSN',
    path => "metadata.eprint.issn",
    expand => 0,
  },
  {
    alias => 'JT',
    path => "metadata.eprint.publication",
    expand => 0,
  },
  {
    alias => 'KW',
    path => "metadata.eprint.keywords",
    expand => 0,
  },
  {
    alias => 'NA',
    path => "metadata.eprint.contributor_search.name",
    expand => 0,
  },
  {
    alias => 'OA',
    path => "metadata.eprint.oa_status_search",
    expand => 0,
  },
  {
    alias => 'ORCID',
    path => "metadata.eprint.contributor_search.orcid",
    expand => 0,
  },
  {
    alias => 'ORG',
    path => "metadata.eprint.contributor_search.organisation",
    expand => 0,
  },
  {
    alias => 'PB',
    path => "metadata.eprint.publisher",
    expand => 0,
  },
  {
    alias => 'PG',
    path => "metadata.eprint.pagerange",
    expand => 0,
  },
  {
    alias => 'PMID',
    path => "metadata.eprint.pubmedid",
    expand => 0,
  },
  {
    alias => 'PY',
    path => 'agg_pubyear_key',
    expand => 0,
    range => 1,
  },
  {
    alias => 'RL',
    path => "metadata.eprint.contributor_search.role",
    expand => 0,
  },
  {
    alias => 'SE',
    path => "metadata.eprint.series",
    expand => 0,
  },
  {
    alias => 'TI',
    path => "metadata.eprint.title",
    expand => 1,
  },
  {
    alias => 'TY',
    path => "agg_pubtype",
    expand => 1,
  },
  {
    alias => 'VL',
    path => "metadata.eprint.volume",
    expand => 0,
  },
];
