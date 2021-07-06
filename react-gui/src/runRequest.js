export default async function runRequest(body) {
  const response = await fetch("/cgi/{repositoryname}/es-{repositoryname}-proxy", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body)
  });
  return response.json();
}

