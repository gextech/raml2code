_ = require('lodash')
utilSchemas = require('../util/schemas')
parseResource = require('../util/parseResource')
commonHelpers = require("../helpers/common").helpers()

generator = {}
generator.helpers = commonHelpers
generator.template = require("./tmpl/jaxrsResources.hbs")

customAdapter = (method, methodParsed) ->
  if methodParsed.formData
    methodParsed.consumes = "MediaType.MULTIPART_FORM_DATA"

generator.parser = (data) ->
  parsed = []
  schemas = utilSchemas.loadSchemas(data)

  options =
    annotations :
      path: "@PathParam"
      query: "@QueryParam"
      body: ""
      multiPart: "@FormDataParam"
      form: "@FormDataParam"
    mapping :
      'string' : "String"
      'boolean' : "Boolean"
      'number' : "BigDecimal"
      'integer' : "Long"
      'array' : "List"
      'object' : "Map"
      'file' : "InputStream"

  methodParse = []

  for resource in data.resources
    methodParse.push parseResource(resource, options, schemas, customAdapter)

  methodParse = _.flatten(methodParse)
  resourceGroup = _.groupBy(methodParse, (method) ->
    method.displayName
  )

  if data.extra
    data.extra.package = "#{data.extra.package}.#{data.version}"
    data.extra.importPojos = "#{data.extra.importPojos}.#{data.version}"
  for k,v of resourceGroup
    model = {}
    model.extra = data.extra
    first = _.first(v)
    model.uri = first.uri
    model.className = "#{first.displayName}Resource"
    model.methods = v
    result = {}
    version =  if data.version then "#{data.version}/"  else ""
    result["#{version}#{model.className}.groovy"] = model
    parsed.push result
  parsed


module.exports = generator
