###############################################################################
#
#  Elasticsearch Export Plugin configuration
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
# A list of Elasticsearch Export Plugins
# order: Standard first, other a-z

$c->{es}->{export_plugins} = [ 
  {
    name => 'Export::ZORACSV',
    label => 'ZORA CSV',
    order => '10',
    vis_level => 'all',
  },
  {
    name => 'Export::AKABER',
    label => 'AKABER',
    order => '20',
    vis_level => 'all',
  },
  {
    name => 'Export::BibTeX',
    label => 'BibTeX',
    order => '25',
    vis_level => 'all',
  },
  {
    name => 'Export::Citavi',
    label => 'Citavi',
    order => '30',
    vis_level => 'all',
  },
  {
    name => 'Export::DC_Ext',
    label => 'Dublin Core',
    order => '35',
    vis_level => 'all',
  },
  {
    name => 'Export::XML',
    label => 'EP3 XML',
    order => '40',
    vis_level => 'all',
  },
  {
    name => 'Export::XMLFiles',
    label => 'EP3 XML (Docs)',
    order => '45',
    vis_level => 'staff',
  },
  {
    name => 'Export::EndNote',
    label => 'EndNote',
    order => '50',
    vis_level => 'all',
  },
  {
    name => 'Export::Evaluation',
    label => 'Evaluation',
    order => '55',
    vis_level => 'all',
  },
  {
    name => 'Export::HTML',
    label => 'HTML Citation',
    order => '60',
    vis_level => 'all',
  },
  {
    name => 'Export::IRO',
    label => 'IRO - UZH',
    order => '65',
    vis_level => 'all',
  },
  {
    name => 'Export::JSON',
    label => 'JSON',
    order => '70',
    vis_level => 'all',
  },
  {
    name => 'Export::MARC21XML',
    label => 'MARC21 XML',
    order => '75',
    vis_level => 'all',
  },
  {
    name => 'Export::METS',
    label => 'METS',
    order => '80',
    vis_level => 'all',
  },
  {
    name => 'Export::CSV',
    label => 'CSV',
    order => '85',
    vis_level => 'all',
  },
  {
    name => 'Export::MultilineCSV',
    label => 'CSV (Staff)',
    order => '90',
    vis_level => 'staff',
  },
  {
    name => 'Export::Ids',
    label => 'Object IDs',
    order => '95',
    vis_level => 'all',
  },
];
