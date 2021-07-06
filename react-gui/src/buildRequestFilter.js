function getTermFilterValue(field, fieldValue) {
  // We do this because if the value is a boolean value, we need to apply
  // our filter differently. We're also only storing the string representation
  // of the boolean value, so we need to convert it to a Boolean.


  // TODO We need better approach for boolean values
  if (fieldValue === "false" || fieldValue === "true") {
    return { [field]: fieldValue === "true" };
  }
  
  return { [`${field}`]: fieldValue }; 
}

function getTermFilter(filter) {
  if (filter.type === "any") {
    return {
      bool: {
        should: filter.values.map(filterValue => ({
          term: getTermFilterValue(filter.field, filterValue)
        })),
        minimum_should_match: 1
      }
    };
  } else if (filter.type === "all") {
    return {
      bool: {
        filter: filter.values.map(filterValue => ({
          term: getTermFilterValue(filter.field, filterValue)
        }))
      }
    };
  }
}

export default function buildRequestFilter(filters) {
  if (!filters) return;
  
  filters = filters.reduce((acc, filter) => {
    for (let i = 0; i < window.conf_aggs.length; i++) {
      if (
        window.conf_aggs[i].includes(filter.field)) {
        return [...acc, getTermFilter(filter)];
      }  
    }
    return acc;
  }, []);
  
  if (filters.length < 1) return;
  return filters;
}

/*
function getRangeFilter(filter) {
  if (filter.type === "any") {
    return {
      bool: {
        should: filter.values.map(filterValue => ({
          range: {
            [filter.field]: {
              ...(filterValue.to && { lt: filterValue.to }),
              ...(filterValue.to && { gt: filterValue.from })
            }
          }
        })),
        minimum_should_match: 1
      }
    };
  } else if (filter.type === "all") {
    return {
      bool: {
        filter: filter.values.map(filterValue => ({
          range: {
            [filter.field]: {
              ...(filterValue.to && { lt: filterValue.to }),
              ...(filterValue.to && { gt: filterValue.from })
            }
          }
        }))
      }
    };
  }
}

export default function buildRequestFilter(filters) {
  if (!filters) return;

  
    filters = filters.reduce((acc, filter) => {
    if (
      [
        "agg_pubyear_key",
        "agg_name_key",
        "agg_subject_de",
        "agg_subject_en",
        "agg_pubtype_de",
        "agg_pubtype_en",
        "agg_hasfulltext_de",
        "agg_hasfulltext_en",
        "agg_accessrights_de",
        "agg_accessrights_en",
        "agg_journalseries_key",
        "agg_dewey_de",
        "agg_dewey_en",
        "agg_language_de",
        "agg_language_en",
        "agg_affiliation_key"   
      ].includes(filter.field)) {
      return [...acc, getTermFilter(filter)];
    }
    return acc;
  }, []);
    
  if (filters.length < 1) return;
  return filters;
}
*/