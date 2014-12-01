_ = require('lodash')
deref = require('deref')();
util = {}
util.getUriParameter = (resource, annotation, mapping)->
  uriParameters = []
  for key of resource.uriParameters
    p = resource.uriParameters[key]
    uriParameters.push util.mapProperty(p, key, annotation, mapping).property
  uriParameters

util.getQueryparams = (queryParams, annotation, mapping)->
  params = []
  for key of queryParams
    p = queryParams[key]
    params.push util.mapProperty(p, key, annotation, mapping).property
  params

util.parseForm = (body, annotations, mapping) ->
  args = []
  if body and (body['multipart/form-data'] or body["application/x-www-form-urlencoded"])
    form = body["multipart/form-data"] or body["application/x-www-form-urlencoded"]
    if body["multipart/form-data"] isnt undefined
      annotation = annotations.multiPart
    else
      annotation = annotations.form
    data = form.formParameters or form.formParameters
    for key of data
      p = data[key]
      parsedProperty = util.mapProperty(p, key, annotation, mapping).property
      args.push parsedProperty
      if parsedProperty.type is "InputStream"
        args.push {name: parsedProperty.name + "Data" , type: "FormDataContentDisposition", kind: annotation + "(\"#{parsedProperty.name}\")"}
  args

util.mapProperties = (expandedSchema, refMap, mapping)->
  data = {}
  data.classMembers = []
  data.innerClasses = []
  for key of expandedSchema.properties
    property = expandedSchema.properties[key]
    property.required = true if expandedSchema.required and _.contains(expandedSchema.required, key)

    propParsed = util.mapProperty(property, key, '', mapping, refMap)
    data.classMembers.push propParsed.property
    data.innerClasses.push propParsed.innerClass if propParsed.innerClass

  data

util.resolveTypeByRef = (keyRef, refMap)->
  innnerSchema = deref.util.findByRef(keyRef, refMap)
  type = ""
  if innnerSchema and innnerSchema.title
    type = util.capitalize(innnerSchema.title)
  else if keyRef
    console.error "$ref not found: #{keyRef} }"
  type

util.mapProperty = (property, name, annotation, mapping, refMap)->
  data = {}
  data.property = {}
  data.property.name = name
  data.property.notNull =  true if property.required
  data.property.size = []
  data.property.size.push {"name" : "min", "value" : property.minLength} if property.minLength
  data.property.size.push {"name" : "max", "value" : property.maxLength} if property.maxLength

  data.property.comment =  property.description
  if property.items and property.items["$ref"]
    keyRef = property.items["$ref"]
  else if property["$ref"] 
    keyRef = property["$ref"]

  switch property.type
    when 'array'
      auxType = "List"
      if keyRef
        auxType += "<#{util.resolveTypeByRef(keyRef, refMap)}>"
      data.property.type = auxType

    when 'object'
      #if object has no references we made a inner class
      if property.properties
        if not property.title
          console.error "Please provide a title for property:", name
        data.property.type = util.capitalize(property.title)
        data.innerClass = {}
        data.innerClass.className = data.property.type
        data.innerClass.classDescription = property.description
        aux = util.mapProperties(property, refMap, mapping)
        data.innerClass.classMembers = aux.classMembers
      else if keyRef
        data.property.type = util.resolveTypeByRef(keyRef, refMap)
      else
        data.property.type = 'Map'
    when 'string' then data.property.type = mapping[property.type]
    when 'boolean' then data.property.type = mapping[property.type]
    when 'number' then data.property.type = mapping[property.type]
    when 'integer' then data.property.type = mapping[property.type]
    when 'file' then data.property.type = mapping[property.type]


  if data.property.type == "BigDecimal"
    data.property.decimalMax = property.maximum
    data.property.decimalMin = property.minimum
  else if data.property.type == "Long"
    data.property.max =  property.maximum
    data.property.min = property.minimum


  data.property.kind = annotation + "(\"#{data.property.name}\")"
  data



util.parseResource = (resource, parsed, annotations, mapping, parentUri = "", parentUriArgs = []) ->

  for m in resource.methods
    methodDef = {}
    methodDef.uri = parentUri + resource.relativeUri
    uriArgs = util.getUriParameter(resource, annotations.path, mapping)
    methodDef.args = parentUriArgs.concat(uriArgs)
    methodDef.args = methodDef.args.concat(util.getQueryparams(m.queryParameters, annotations.query, mapping))
    methodDef.args = methodDef.args.concat(util.parseForm(m.body, annotations, mapping))
    request = util.parseSchema(m.body,  "#{methodDef.uri} body" )
    respond = util.parseSchema(util.getBestValidResponse(m.responses).body,  "#{methodDef.uri} response" )
    if request.title
      methodDef.args = methodDef.args ? []
      methodDef.args.push {'kind': annotations.body, 'type': util.capitalize(request.title), 'name': request.title.toLowerCase()}

    methodDef.request = request.title ? null
    methodDef.respond = respond.title
    methodDef.annotation = m.method.toUpperCase()
    formData = _.find(methodDef.args, (arg)->
      arg.type is "InputStream"
    )
    if formData
      methodDef.consumes = "MediaType.MULTIPART_FORM_DATA"
    methodDef.name = m.method + resource.displayName
    methodDef.displayName = resource.displayName
    parsed.push methodDef
  if resource.resources
    for innerResource in resource.resources
      util.parseResource(innerResource, parsed, annotations, mapping, methodDef.uri, uriArgs)
  undefined


util.parseSchema = (body, meta = '') ->
  schema = {}
  if body and body['application/json']
    try
      schema = JSON.parse(body['application/json'].schema)
    catch e
      console.log "-----JSON ERROR on #{meta}---------"
      console.log body['application/json'].schema
      throw e


  schema

util.getBestValidResponse = (responses) ->
  response = responses["304"] ?
    response = responses["204"] ?
    response = responses["201"] ?
    response = responses["200"] ?
    response

util.capitalize = (str)->
  str.charAt(0).toUpperCase() + str.slice(1)

util.sanitize = (str)->
  aux = str.split(".")
  res = ''
  aux.forEach (it)->
    res += util.capitalize(it)
  res

module.exports = util
