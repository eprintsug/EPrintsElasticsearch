#!/bin/bash


dir="../../../cfg/apache"
for f in "$dir"/*.conf; do
  filename=$(basename -- "$f")
  APP_NAME="${filename%.*}"
done

cp build/static/js/main.*.js ../static/javascript/elastic_search.main.js
cp build/static/css/main.*.css ../static/style/elastic_search.main.css
cp public/manifest.json  ../static/javascript/manifest.json

echo Building scripts and sheets for repository: ${APP_NAME}
../../../bin/generate_static --verbose ${APP_NAME}



