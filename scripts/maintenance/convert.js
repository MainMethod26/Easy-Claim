const postmanToOpenApi = require('postman-to-openapi')

async function run() {
  try {
    await postmanToOpenApi('EasyClaim.postman_collection.json', 'src/openapi.yml', { defaultTag: 'General' })
    console.log('Successfully converted Postman collection to OpenAPI')
  } catch (err) {
    console.error(err)
  }
}
run()
