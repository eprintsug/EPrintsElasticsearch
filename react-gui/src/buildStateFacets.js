function getValueFacet(aggregations, fieldName) {
  if (
    aggregations &&
    aggregations[fieldName] &&
    aggregations[fieldName].buckets &&
    aggregations[fieldName].buckets.length > 0
  ) {
    return [
      {
        field: fieldName,
        type: "value",
        data: aggregations[fieldName].buckets.map(bucket => ({
          // Boolean values and date values require using `key_as_string`
          value: bucket.key_as_string || bucket.key,
          count: bucket.doc_count
        }))
      }
    ];
  }
}

export default function buildStateFacets(aggregations,my_conf_aggs) {

  const my_conf_aggs_value= [];
  if (my_conf_aggs) {
    for (let i = 0; i < my_conf_aggs.length; i++) {
      my_conf_aggs_value[i] = getValueFacet(aggregations, my_conf_aggs[i]);
      
    }
  };
  
  var facets = {};
  if (my_conf_aggs) {
    for (let i = 0; i < my_conf_aggs.length; i++) {
      facets[my_conf_aggs[i]] = my_conf_aggs_value[i];
      
    }
  };

  if (Object.keys(facets).length > 0) {
    return facets;
  }
}

/*
function getRangeFacet(aggregations, fieldName) {
  if (
    aggregations &&
    aggregations[fieldName] &&
    aggregations[fieldName].buckets &&
    aggregations[fieldName].buckets.length > 0
  ) {
    return [
      {
        field: fieldName,
        type: "range",
        data: aggregations[fieldName].buckets.map(bucket => ({
          // Boolean values and date values require using `key_as_string`
          value: {
            to: bucket.to,
            from: bucket.from,
            name: bucket.key
          },
          count: bucket.doc_count
        }))
      }
    ];
  }
}

*/
/* old stuff
  const agg_pubyear_key       = getValueFacet(aggregations, "agg_pubyear_key");
  const agg_name_key          = getValueFacet(aggregations, "agg_name_key");
  const agg_subject_de        = getValueFacet(aggregations, "agg_subject_de");
  const agg_subject_en        = getValueFacet(aggregations, "agg_subject_en");
  const agg_pubtype_de        = getValueFacet(aggregations, "agg_pubtype_de");
  const agg_pubtype_en        = getValueFacet(aggregations, "agg_pubtype_en");
  const agg_hasfulltext_de    = getValueFacet(aggregations, "agg_hasfulltext_de");
  const agg_hasfulltext_en    = getValueFacet(aggregations, "agg_hasfulltext_en");
  const agg_accessrights_de   = getValueFacet(aggregations, "agg_accessrights_de");
  const agg_accessrights_en   = getValueFacet(aggregations, "agg_accessrights_en");
  const agg_journalseries_key = getValueFacet(aggregations, "agg_journalseries_key");
  const agg_dewey_de          = getValueFacet(aggregations, "agg_dewey_de");
  const agg_dewey_en          = getValueFacet(aggregations, "agg_dewey_en");
  const agg_language_de       = getValueFacet(aggregations, "agg_language_de");
  const agg_language_en       = getValueFacet(aggregations, "agg_language_en");
  const agg_affiliation_key   = getValueFacet(aggregations, "agg_affiliation_key");
  
  const facets = {
    ...(agg_pubyear_key && { agg_pubyear_key }),
    ...(agg_name_key && { agg_name_key }),
    ...(agg_subject_de && { agg_subject_de }),
    ...(agg_subject_en && { agg_subject_en }),
    ...(agg_pubtype_de && { agg_pubtype_de }),
    ...(agg_pubtype_en && { agg_pubtype_en }),
    ...(agg_hasfulltext_de && { agg_hasfulltext_de }),
    ...(agg_hasfulltext_en && { agg_hasfulltext_en }),
    ...(agg_accessrights_de && { agg_accessrights_de }),
    ...(agg_accessrights_en && { agg_accessrights_en }),
    ...(agg_journalseries_key && { agg_journalseries_key }),
    ...(agg_dewey_de && { agg_dewey_de }),
    ...(agg_dewey_en && { agg_dewey_en }),
    ...(agg_language_de && { agg_language_de }),
    ...(agg_language_en && { agg_language_en }),
    ...(agg_affiliation_key && { agg_affiliation_key })
  };
  */
 