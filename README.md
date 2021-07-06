# Elasticsearch
Search EPrints on Elasticsearch

The EPrints - Elasticsearch integration has been developed at University of Zurich (UZH) by

* Martin Brändle - Data model, mapping and indexing methods, ESIndex plugin and ESadmin script
* Jens Witzel - React GUI, Search Proxy, Export Proxy

It has been presented at OR2021 during the presentation of EPrints at the Repository Rodeo.

We provide the software here as is, with sufficient documentation for integration with other EPrints repositories. However, each repository has its individual data structure, which requires configuration, modification of the mapping and indexing methods and the GUI parts (facets) on your own. Please not that we are not able to provide any support. To learn about Elasticsearch, it is recommended to visit the Elasticsearch webinars or the Elasticsearch Engineering trainings.


## Features

For the end user:
* full-fledged, fast and scalable search engine
* facets for drill-down of results
* hit-highlighting in results
* display of result snippets for abstract and fulltext. Depending on document security and user role, these are displayed or hidden
* extended query language using field aliases such as TI, AB, AU, KW and more
* autosuggest upon typing
* multilingual searches
* fully responsive for mobile view
* flexible export options

For the repository IT administrator:
* versatile data model, configurable to the needs of the repository
* ESadmin script for index creation, reindex, repair, and various other tasks
* automatic index updates using triggers
* blazing fast indexing (10x faster than Xapian on EPrints) and search
* high index security due to hosting of the index and its replicas on an Elasticsearch server. No file locks
* ES service and index can be hosted locally or via cloud service


## Requirements

Elasticsearch and Kibana 7.x ("the ELK stack") running on a dedicated host. Please refer to the [Elastic documentation](https://www.elastic.co/start) on how to get Elasticsearch and Kibana, for installation and configuration.
For production, we recommend a cluster setup with 3 nodes or more because to guarantee cluster and index health. For testing purposes, a single-node setup is sufficient.

[CPAN Search::Elasticsearch library](https://metacpan.org/pod/Search::Elasticsearch) including dependencies installed on your repository host.


## General Design and Working Principle

_"The repository is the proxy."_

All data flows (queries, facets, results, index data) run via an ES proxy or ES plugin on the EPrints repository. The repository

* augments the query coming from the browser
* is responsible for all communication with the ES server
* hides credentials from end user's browser
* augments results and facets with local phrases, links to detail page, error messages in the chosen language
* augments results with document properties such as preview thumbnail or other
* handles document security (display of fulltext snippet based on document security settings and user role)


#### Data Flow

Index event via script or trigger <--> ESIndex plugin on repository <--> Elasticsearch

Queries, Facets, Results <--> ES proxy on repository <--> Elasticsearch



## Installation

Install the CPAN Search::Elasticsearch module and its dependencies.

Copy the files in this GitHub repository accordingly to your repository directory structure.

Set up or let set up an Elasticsearch host.

Set up your prefered local develop environment for the react code. E.g. 
* Visual Studio - https://code.visualstudio.com/download or
* Eclipse - https://www.eclipse.org/downloads/
 
Set up Node.js -  https://nodejs.org/de/download/

## Configuration

Your Elasticsearch administrator must set up:

* one admin account with credentials (username, password) to manage the Elasticsearch index of the reposity. The following rights must be given: Cluster/manage, Indices/all
* one user account with credentials (username, password) to read the Elasticsearch index of the repository. The following rights must be given: Indices/read, Indices/view index metadata
* preferably, an Elasticsearch index pattern that serves as name schema for the index  (for example: "institution_reponame_*" )

In cfg.d/z_elasticsearch.pl , configure the following parameters:

```
$c->{es}->{host} =           [
                                'host1.domain.com',
                                'host2.domain.com',
                                'host3.domain.com',
                             ];
$c->{es}->{index} =          'name_of_es_index';
$c->{es}->{info}->{admin} =  'es_index_admin:password';
$c->{es}->{info}->{user} =   'es_index_user:password';
$c->{es}->{static_settings} = {
        "number_of_shards" => 1,
        "number_of_replicas" => 2,
};
```

$c->{es}->{host} is configured here for a Elasticsearch host with 3 nodes. If you have only a 1-node cluster, remove two node names and set "number_of_replicas" to 0.

As a rule of thumb, 1 shard should be used per 50GB of Elasticsearch index size, so, in most cases, 1 is sufficient.

'name_of_es_index' should match the index pattern you were given by the Elasticsearch administrator. E.g. for UZH, it is 'uzh_zora_*' , the index name is e.g. uzh_zora_zoraprod

Next, the data model must be configured.


## Data model (mapping and indexing)

Prior, an ES index requires a mapping (the data model). The ESIndex plugin and the configurations here provide a mapping - but you need to adapt the mapping and index methods for your repository.

* The mapping is instantiated the first time the index is created, using `ESadmin create_index`.
* If you add new fields to your repository, one can and should update the mapping of the ES index using `ESadmin update_mapping`.
* If you delete fields or change a field definition in your repository, you should erase and recreate the ES index.

Elasticsearch supports complex data models using nested data.

As it is implemented here, the basic entity in the Elasticsearch repository index is the eprint. It has the following coarse model:

id             (the eprint id)
aggregations   (facets)
metadata       (the eprint fields)
citation       (the citation(s) of your eprint, indexed because of performance)
documents      (document dataset data)
fulltext       (fulltext data, using language analyzers)

The ESIndex.pm plugin provides an abstract method, create_mapping().
It calls sub methods depending on

aggregation name
field name  (mostly used for commpound fields)
field type
citation name
document data
fulltext

These methods are defined in archives/{repositoryname}/cfg/cfg.d/z_elasticsearch_mappings.pl. See documentation there.

A mapping method name has the following format:
* $c->{es_mapping_eprint_*fieldname*} for specific fields (mostly compound fields). You should adapt those to your repository.
* $c->{es_mapping_type_*fieldtype*} for generic field types (e.g. boolean). For most of the common field types in EPrints a corresponding method has been implemented.
* citation, document data, fulltext and aggregations have specific methods, which need to be inspected and adapted, too.

Also, in z_elasticsearch_mappings.pl, a list of fields not to be indexed can be configured in `$c->{es}->{field_exclusions}`


Similarly, ESIndex.pm provides an abstract method for indexing, index_fields(). It calls the associated indexing sub methods defined in

archives/{repositoryname}/cfg/cfg.d/z_elasticsearch_index.pl

An index method name has the following format:
* $c->{es_index_eprint_*fieldname*} for specific fields (mostly compound fields). You should adapt those to your repository.
* $c->{es_index_type_*fieldtype*} for generic field types (e.g. boolean)
* citation, document data, fulltext and aggregations have specific methods, which need to be inspected and adapted, too.

## Further configuration files

cfg.d/z_elasticsearch_aggregations.pl  - Aggregations (facets)
cfg.d/z_elasticsearch_aliased.pl - Field aliases for queries
cfg.d/z_elasticsearch_export_plugins.pl - Export plugin configuration
cfg.d/z_elasticsearch_trigger.pl - Trigger methods, no change needed


## Creating an Elasticsearch Index

After you have configured everything, reload the configuration by restarting the web server and create the index using

```
cd {eprints_root}/bin
sudo -u {apacheuser} ./ESadmin erase_index {repositoryname}
sudo -u {apacheuser} ./ESadmin create_index {repositoryname}
screen
sudo -u {apacheuser} ./ESadmin reindex {repositoryname} eprint –direct --verbose
```

Before using the create_index and erase_index commands, the EPrints "indexer" (event queue processor) should be stopped. This avoids that index events are processed which may refer to a prior Elasticsearch index mapping.

For a description of all functions of ESadmin, use

```
cd {eprints_root}/bin
perldoc ESadmin
```

## Setting up the GUI

### The GUI itselves

Take the sources and libs from the react directory, unpack them localy into {install_dir}

* cd {install_dir}
* npm install
* npm install react-loader-spinner –save
* edit File .env and make yout Host and Path changes:
```
ELASTICSEARCH_HOST=https://{yourhost}
ELASTICSEARCH_HOST_PATH=https://{yourhost}/cgi/es-{repositoryname}-proxy
```
* edit /src/ResultView.js if you want to make changes to your citation. If you do not want MathJax support, disable LaTeX rendering from  (otherwise add MathJax to your Repo).
* npm run build
* copy last two script commands with hash named js-files from {install_dir}/build/index.html and append them into {install_dir}/build/index.ssi - looks like:
```
<script src="/faceted-search/static/js/2.170f73fc.chunk.js"></script>
<script src="/faceted-search/static/js/main.c09ef916.chunk.js"></script>
```

### The Repository

Now change to your Repo and make some preperation and changes, depending on your supported languages (we offer German (de) and English (en). Our way of multilangual support goes like this:
```
archives/{repositoryname}/html/de/faceted-search
archives/{repositoryname}/html/en/faceted-search
archives/{repositoryname}/cfg/lang/de/static/search/index.xpage 
archives/{repositoryname}/cfg/lang/en/static/search/index.xpage
archives/{repositoryname}/cfg/lang/de/static/help/index.xpage
archives/{repositoryname}/cfg/lang/en/static/help/index.xpage
archives/{repositoryname}/cfg/lang/de/phrases/dynamic.xml
archives/{repositoryname}/cfg/lang/en/phrases/dynamic.xml
archives/{repositoryname}/cfg/lang/de/phrases/faceted_search.xml
archives/{repositoryname}/cfg/lang/en/phrases/faceted_search.xml
[etc,]
```
Note: If you do not have multilangual support: be clever enough to adapt these paths, edit achives/{repositoryname}/cfg/plugins/EPrints/Plugin/FacetedSearch/ESProxy.pm and make changes on all "de" / "en" parts.

* make your apache do work with ServerSideIncludes (SSI). Later we will change that to be solved a smarter way.
* mkdir archives/{repositoryname}/html/de/faceted-search; ln -s archives/{repositoryname}/html/en/faceted-search archives/{repositoryname}/html/de/faceted-search
* edit all archives/{repositoryname}/ files and change {repositoryname} and {yourhost} for your purposes.
* upload all local React code from {install_dir}/build to your Repo archive HTML archives/{repositoryname}/html/de/faceted-search
* install the phrases and edit them to make changes if needed.
* restart your server.
* make a Browser Check: https://{yourhost}/search/ or any single Repo page. If you run into problems, take a quick look at apaches error log file.

## Faceted Search

Help on the various search options is available on https://www.zora.uzh.ch/help/#FacetedSearch

Or try it live on [ZORA](https://www.zora.uzh.ch)
